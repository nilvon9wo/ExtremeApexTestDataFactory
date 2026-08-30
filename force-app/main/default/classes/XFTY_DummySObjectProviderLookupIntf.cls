/**
 * Resolves which Provider should generate a given record.
 *
 * Most implementations should compose an {@link XFTY_SObjectProviderLookup},
 * which implements all three methods on top of a `register(key, provider)` call.
 */
public interface XFTY_DummySObjectProviderLookupIntf {
    /** Convenience for the common case; equivalent to `get(XFTY_LookupKey.get(sObjectType))`. */
    XFTY_DummySobjectProviderIntf get(SObjectType sObjectType);

    /** Resolve a Provider for an explicit variant key. */
    XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey);

    /**
     * Every registered key whose `isInstanceOf(sObj)` is true. Used when a
     * relationship supplies only an override template: the caller picks the most
     * specific match. Empty when nothing refined matches - the caller falls back
     * to `XFTY_LookupKey.get(sObj.getSObjectType())`.
     */
    Set<XFTY_LookupKeyIntf> keysFor(SObject sObj);
}
