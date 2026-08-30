/**
 * The state that every step of a single generation run needs to see: which
 * Provider Lookup to resolve variants through, whether (and when) to insert, how
 * far to follow relationships, and - during the context-aware value pass - the
 * record currently being built and the records generated for its relationships.
 *
 * Before this class the first three values were passed as separate arguments
 * through the whole factory call tree and the
 * `XFTY_DummySobjectProviderIntf.createBundle` contract. Bundling them:
 *
 * - shortens every signature in the engine;
 * - gives one place to apply the recursion transforms (`RELATED_ONLY` becomes
 *   `NOW` for related records, `PREVENT_CASCADE` becomes `NONE` one level down) -
 *   see {@link #forRelated};
 * - is what a context-aware value strategy reads (see
 *   {@link XFTY_ContextAwareValueIntf}, docs/design/context-aware-values.md).
 *
 * `recordBeingBuilt` / `ancestorBundle` / `rowIndex` are populated only for the
 * per-record value pass (via {@link #forRecord}); everywhere else they are null /
 * -1.
 *
 * Immutable. Derive a new one with {@link #forRelated} / {@link #forRecord}
 * rather than mutating.
 */
@IsTest
public class XFTY_GenerationContext {
    public final XFTY_DummySObjectProviderLookupIntf providerLookup;
    public final XFTY_InsertModeEnum insertMode;
    public final XFTY_InsertInclusivityEnum inclusivity;

    /** The record whose value is being generated - only set during the context-aware pass. */
    public final SObject recordBeingBuilt;
    /** The bundle of records generated for `recordBeingBuilt`'s relationships. Read with `getList(relationshipField)`. */
    public final XFTY_DummySObjectBundle ancestorBundle;
    /** Which row of a multi-record generation `recordBeingBuilt` is - the index into the ancestor bundle's lists. */
    public final Integer rowIndex;

    public XFTY_GenerationContext(
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        this(providerLookup, insertMode, inclusivity, null, null, -1);
    }

    private XFTY_GenerationContext(
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity,
            SObject recordBeingBuilt,
            XFTY_DummySObjectBundle ancestorBundle,
            Integer rowIndex
    ) {
        if (providerLookup == null) {
            throw new XFTY_DummySObjectFtyProviderException('A generation context requires a Provider Lookup.');
        }
        this.providerLookup = providerLookup;
        this.insertMode = (insertMode == null) ? XFTY_InsertModeEnum.NEVER : insertMode;
        this.inclusivity = (inclusivity == null) ? XFTY_InsertInclusivityEnum.NONE : inclusivity;
        this.recordBeingBuilt = recordBeingBuilt;
        this.ancestorBundle = ancestorBundle;
        this.rowIndex = rowIndex;
    }

    /**
     * The context for generating one level of related (ancestor) records:
     *
     * - `RELATED_ONLY` becomes `NOW` - the parents of a not-inserted primary
     *   record are still inserted;
     * - `PREVENT_CASCADE` becomes `NONE` - the direct relationships are generated
     *   but they do not generate their own.
     *
     * Every other mode / inclusivity is carried through unchanged; the per-record
     * fields are cleared.
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

    /**
     * The context for evaluating a context-aware value on `record` (row
     * `rowIndex` of the generation), with `ancestorBundle` holding the records
     * generated for its relationships. Mode / lookup / inclusivity are unchanged.
     */
    public XFTY_GenerationContext forRecord(SObject record, XFTY_DummySObjectBundle ancestorBundle, Integer rowIndex) {
        return new XFTY_GenerationContext(
                this.providerLookup, this.insertMode, this.inclusivity, record, ancestorBundle, rowIndex
        );
    }
}
