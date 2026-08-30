/**
 * Resolves which Provider should generate a given record.
 *
 * Most implementations should extend {@link XFTY_AbstractSObjectProviderLookup},
 * which implements all three methods on top of a `register(key, providerType)`
 * call, and only register their keys.
 */
public interface XFTY_DummySObjectProviderLookupIntf {
    /** Convenience for the common case; equivalent to `get(XFTY_LookupKey.get(sObjectType))`. */
    XFTY_DummySobjectProviderIntf get(SObjectType sObjectType);

    /** Resolve a Provider for an explicit variant key. */
    XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey);

    /**
     * Derive the best-matching registered key for a record (used when a
     * relationship supplies only an override template). Falls back to a plain
     * `XFTY_LookupKey` for the record's SObject type.
     */
    XFTY_LookupKeyIntf keyFor(SObject sObj);
}
