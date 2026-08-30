/**
 * The state that every step of a single generation run needs to see: which
 * Provider Lookup to resolve variants through, whether (and when) to insert, and
 * how far to follow relationships.
 *
 * Before this class those three values were passed as separate arguments through
 * the whole factory call tree and the `XFTY_DummySobjectProviderIntf.createBundle`
 * contract. Bundling them:
 *
 * - shortens every signature in the engine;
 * - gives one place to apply the recursion transforms (`RELATED_ONLY` becomes
 *   `NOW` for related records, `PREVENT_CASCADE` becomes `NONE` one level down) -
 *   see {@link #forRelated};
 * - is the extension point for context-aware value generation and the
 *   shared-ancestor insert-mode declaration (see docs/future-ideas.md and
 *   docs/design/shared-ancestors.md). Those will add fields here (the record
 *   being built, the generated ancestor bundle); today it carries only what the
 *   engine already threaded.
 *
 * Immutable. Derive a new one with {@link #forRelated} rather than mutating.
 */
@IsTest
public class XFTY_GenerationContext {
    public final XFTY_DummySObjectProviderLookupIntf providerLookup;
    public final XFTY_InsertModeEnum insertMode;
    public final XFTY_InsertInclusivityEnum inclusivity;

    public XFTY_GenerationContext(
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        if (providerLookup == null) {
            throw new XFTY_DummySObjectFtyProviderException('A generation context requires a Provider Lookup.');
        }
        this.providerLookup = providerLookup;
        this.insertMode = (insertMode == null) ? XFTY_InsertModeEnum.NEVER : insertMode;
        this.inclusivity = (inclusivity == null) ? XFTY_InsertInclusivityEnum.NONE : inclusivity;
    }

    /**
     * The context for generating one level of related (ancestor) records:
     *
     * - `RELATED_ONLY` becomes `NOW` - the parents of a not-inserted primary
     *   record are still inserted;
     * - `PREVENT_CASCADE` becomes `NONE` - the direct relationships are generated
     *   but they do not generate their own.
     *
     * Every other mode / inclusivity is carried through unchanged.
     */
    public XFTY_GenerationContext forRelated() {
        return new XFTY_GenerationContext(
                this.providerLookup,
                XFTY_InsertModeEnum.RELATED_ONLY.equals(this.insertMode)
                        ? XFTY_InsertModeEnum.NOW
                        : this.insertMode,
                XFTY_InsertInclusivityEnum.PREVENT_CASCADE.equals(this.inclusivity)
                        ? XFTY_InsertInclusivityEnum.NONE
                        : this.inclusivity
        );
    }
}
