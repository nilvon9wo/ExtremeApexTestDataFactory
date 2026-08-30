/**
 * How a related record should be produced for a lookup / master-detail field.
 *
 * Whether the relationship is *required* or *optional* is not part of this
 * contract - that is decided by which slot it occupies on the Master Template
 * (`putRequired` vs `putOptional`). This lets a single
 * implementation - including a future shared-ancestor implementation - be used
 * in either slot.
 */
public interface XFTY_DummyDefaultRelationshipIntf {
    /** Override template for the generated parent; also identifies its SObject type. */
    SObject getOverrideTemplate();

    /**
     * The parent field whose value is copied into the child's lookup field, or
     * null to use the parent's Id.
     */
    SObjectField getRelatedField();

    /**
     * The lookup key identifying which Provider variant generates the parent.
     * Returns the explicit key if one was supplied, otherwise derives one from
     * the override template via `providerLookup.keyFor(...)`. The result is
     * memoised on first call.
     */
    XFTY_LookupKeyIntf resolveLookupKey(XFTY_DummySObjectProviderLookupIntf providerLookup);
}
