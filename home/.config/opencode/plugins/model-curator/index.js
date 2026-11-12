import { Plugin } from "@opencode/plugin";

// Region markers used in catalog display names, e.g. "Claude Sonnet 5.5 (Global)".
const REGION_SUFFIX = /\s*\((?:Global|US|EU|AU|JP|India|APAC|CA|UK)\)\s*$/;

/**
 * model-curator: curates the model picker.
 *
 * Options (all optional):
 *   allowlists   { [providerID]: modelID[] }  Only these models are kept for
 *                                             the provider. Providers without
 *                                             an entry keep all their models.
 *   labels       { [providerID]: string }     Appends " [label]" to the
 *                                             display name of that provider's
 *                                             models, e.g. "Claude Opus 5.5
 *                                             [Vertex AI]".
 *   alphabetize  boolean (default true)       Orders the picker by display
 *                                             name instead of newest-first.
 *   stripRegion  boolean (default false)      Removes a trailing region
 *                                             marker such as "(Global)" or
 *                                             "(US)" from display names, e.g.
 *                                             for Bedrock cross-region
 *                                             inference profiles. Allowlisting
 *                                             two regions of the same model
 *                                             then yields identical names.
 *
 * Caveat for models defined in opencode.json: OpenCode re-applies a config
 * model's "name" in its own model transform, which runs after this plugin's,
 * so a configured "name" always wins and the label is lost. Omit "name" on
 * config models you want labeled (the display name then defaults to the model
 * ID), or write the label into the name yourself.
 */
export default Plugin.define({
  id: "model-curator",

  async setup(ctx) {
    const allowlists = ctx.options.allowlists ?? {};
    const labels = ctx.options.labels ?? {};
    const alphabetize = ctx.options.alphabetize ?? true;
    const stripRegion = ctx.options.stripRegion === true;

    // OpenCode orders models newest-first, so alphabetical order is expressed
    // as synthetic release times counting down from one stable base.
    const sortBase = Date.now();

    await ctx.model.transform((editor) => {
      for (const model of editor.list()) {
        const allowed = allowlists[model.providerID];
        if (Array.isArray(allowed) && !allowed.includes(model.id)) {
          editor.remove(model.providerID, model.id);
          continue;
        }

        const label = labels[model.providerID];
        if (stripRegion || label) {
          editor.update(model.providerID, model.id, (draft) => {
            if (stripRegion) draft.name = draft.name.replace(REGION_SUFFIX, "");
            if (label) draft.name = `${draft.name} [${label}]`;
          });
        }
      }

      if (!alphabetize) return;

      editor
        .list()
        .map(({ providerID, id, name }) => ({ providerID, id, name }))
        .sort(
          (a, b) =>
            a.name.localeCompare(b.name, "en", { numeric: true, sensitivity: "base" }) ||
            a.providerID.localeCompare(b.providerID),
        )
        .forEach(({ providerID, id }, index) => {
          editor.update(providerID, id, (draft) => {
            draft.time.released = sortBase - index * 60_000;
          });
        });
    });
  },
});
