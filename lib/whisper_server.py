#!/usr/bin/env python3
"""
Lightweight persistent Whisper HTTP server.
Loads the Whisper model into GPU/CPU memory once and serves OpenAI-compatible
audio transcription requests at /v1/audio/transcriptions.
"""

import argparse
from email.parser import BytesParser
import email.policy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import signal
import sys
import tempfile
import threading
import time

try:
    import torch
    import whisper
except ImportError as e:
    sys.stderr.write(f"Error importing dependencies: {e}\n")
    sys.stderr.write(
        "Please run this server within the project's virtual environment (.venv).\n"
    )
    sys.exit(1)


model = None
model_lock = threading.Lock()
current_model_name = ""
current_device = ""


def get_default_device() -> str:
    device_env = os.getenv("WHISPER_DEVICE", "").strip().lower()
    if device_env and device_env != "auto":
        return device_env
    if torch.cuda.is_available():
        return "cuda"
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Persistent Whisper HTTP transcription server"
    )
    parser.add_argument(
        "-H",
        "--host",
        default=os.getenv("WHISPER_HOST") or os.getenv("HOST") or "127.0.0.1",
        help="Host to bind to (default: 127.0.0.1 or WHISPER_HOST or HOST)",
    )
    parser.add_argument(
        "-p",
        "--port",
        type=int,
        default=int(os.getenv("WHISPER_PORT") or os.getenv("PORT") or "8765"),
        help="Port to listen on (default: 8765 or WHISPER_PORT or PORT)",
    )
    parser.add_argument(
        "-m",
        "--model",
        default=os.getenv("WHISPER_MODEL") or "turbo",
        help="Whisper model name (default: turbo or WHISPER_MODEL)",
    )
    parser.add_argument(
        "-d",
        "--device",
        default=get_default_device(),
        help="Inference device (cuda, mps, cpu, etc.; default: cuda or mps if available, else cpu)",
    )
    return parser.parse_args()


class WhisperRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Override to format log messages cleanly
        sys.stdout.write(
            f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {self.address_string()} - {format % args}\n"
        )
        sys.stdout.flush()

    def send_json_response(self, status_code: int, data: dict):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        clean_path = self.path.split("?")[0]
        if clean_path in ("/health", "/", "/healthz"):
            self.send_json_response(
                200,
                {
                    "status": "ok",
                    "model": current_model_name,
                    "device": current_device,
                    "cuda_available": torch.cuda.is_available(),
                    "mps_available": (
                        hasattr(torch.backends, "mps")
                        and torch.backends.mps.is_available()
                    ),
                },
            )
        elif clean_path in ("/v1/models", "/models"):
            self.send_json_response(
                200,
                {
                    "object": "list",
                    "data": [
                        {
                            "id": current_model_name,
                            "object": "model",
                            "owned_by": "openai-whisper",
                        }
                    ],
                },
            )
        else:
            self.send_json_response(404, {"error": "Endpoint not found"})

    def do_POST(self):
        clean_path = self.path.split("?")[0]
        if clean_path not in ("/v1/audio/transcriptions", "/audio/transcriptions"):
            self.send_json_response(404, {"error": f"Unknown endpoint: {clean_path}"})
            return

        content_type = self.headers.get("Content-Type", "")
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_json_response(400, {"error": "Invalid Content-Length header"})
            return

        if content_length <= 0:
            self.send_json_response(
                400, {"error": "Content-Length must be greater than zero"}
            )
            return

        body = self.rfile.read(content_length)
        audio_file_path = None
        temp_files_to_clean = []
        language = None

        try:
            if "multipart/form-data" in content_type:
                # Parse multipart form
                hdr = f"Content-Type: {content_type}\r\n\r\n".encode("utf-8")
                msg = BytesParser(policy=email.policy.default).parsebytes(hdr + body)

                for part in msg.iter_parts():
                    name = part.get_param("name", header="content-disposition")
                    filename = part.get_filename()

                    if name == "file":
                        file_data = part.get_payload(decode=True)
                        if file_data:
                            ext = os.path.splitext(filename)[1] if filename else ".m4a"
                            if not ext:
                                ext = ".m4a"
                            tmp = tempfile.NamedTemporaryFile(suffix=ext, delete=False)
                            temp_files_to_clean.append(tmp.name)
                            tmp.write(file_data)
                            tmp.close()
                            audio_file_path = tmp.name
                    elif name in ("path", "file_path"):
                        path_val = part.get_payload(decode=True).decode("utf-8").strip()
                        if path_val and os.path.isfile(path_val):
                            audio_file_path = path_val
                    elif name == "language":
                        lang_val = part.get_payload(decode=True).decode("utf-8").strip()
                        if lang_val:
                            language = lang_val

            elif "application/json" in content_type:
                json_data = json.loads(body.decode("utf-8"))
                path_val = (
                    json_data.get("path")
                    or json_data.get("file_path")
                    or json_data.get("file")
                )
                if path_val and os.path.isfile(path_val):
                    audio_file_path = path_val
                language = json_data.get("language")

            else:
                self.send_json_response(
                    400,
                    {
                        "error": "Unsupported Content-Type. Expected multipart/form-data or application/json"
                    },
                )
                return

            if not audio_file_path or not os.path.isfile(audio_file_path):
                self.send_json_response(
                    400,
                    {
                        "error": "No valid audio file provided in request (via 'file' upload or local 'path')"
                    },
                )
                return

            # Transcribe with model lock to ensure single-threaded execution per instance
            with model_lock:
                start_time = time.time()
                transcribe_kwargs = {
                    "audio": audio_file_path,
                    "condition_on_previous_text": False,
                    "verbose": False,
                }
                if language:
                    transcribe_kwargs["language"] = language

                # Explicitly disable FP16 when running on CPU to avoid UserWarning
                # from Whisper ("FP16 is not supported on CPU; using FP32 instead")
                is_cpu = False
                if hasattr(model, "device"):
                    if isinstance(model.device, torch.device):
                        is_cpu = model.device.type == "cpu"
                    elif isinstance(model.device, str):
                        is_cpu = model.device == "cpu"
                if not is_cpu and current_device == "cpu":
                    is_cpu = True

                if is_cpu:
                    transcribe_kwargs["fp16"] = False

                result = model.transcribe(**transcribe_kwargs)
                elapsed = time.time() - start_time
                self.log_message("Transcription completed in %.2fs", elapsed)

            segments = []
            for i, seg in enumerate(result.get("segments", [])):
                segments.append(
                    {
                        "id": seg.get("id", i),
                        "start": float(seg.get("start", 0.0)),
                        "end": float(seg.get("end", 0.0)),
                        "text": str(seg.get("text", "")).strip(),
                        "avg_logprob": float(seg.get("avg_logprob", 0.0)),
                    }
                )

            resp_payload = {
                "text": str(result.get("text", "")).strip(),
                "language": str(result.get("language", "")),
                "duration": segments[-1]["end"] if segments else 0.0,
                "segments": segments,
            }

            self.send_json_response(200, resp_payload)

        except Exception as e:
            err_msg = str(e)
            sys.stderr.write(f"Transcription error: {err_msg}\n")
            status_code = (
                400
                if (
                    "Failed to load audio" in err_msg
                    or "does not contain any stream" in err_msg
                )
                else 500
            )
            self.send_json_response(status_code, {"error": err_msg})

        finally:
            for tmp_path in temp_files_to_clean:
                if tmp_path and os.path.exists(tmp_path):
                    try:
                        os.remove(tmp_path)
                    except OSError:
                        pass


def main():
    global model, current_model_name, current_device
    args = parse_args()

    current_model_name = args.model
    current_device = args.device

    print(
        f"Loading Whisper model '{current_model_name}' on device '{current_device}'..."
    )
    load_start = time.time()
    model = whisper.load_model(current_model_name, device=current_device)
    load_time = time.time() - load_start
    print(f"Model '{current_model_name}' successfully loaded in {load_time:.2f}s.")

    server = ThreadingHTTPServer((args.host, args.port), WhisperRequestHandler)
    print(f"Whisper server listening on http://{args.host}:{args.port}")
    print(
        f"Whisper transcription endpoint: http://{args.host}:{args.port}/v1/audio/transcriptions"
    )

    def handle_shutdown(signum, frame):
        print(f"\nReceived signal {signum}, shutting down Whisper server...")
        threading.Thread(target=server.shutdown).start()

    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    try:
        server.serve_forever()
    finally:
        server.server_close()
        print("Whisper server stopped.")


if __name__ == "__main__":
    main()
