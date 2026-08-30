/**
 * Identifies which Provider variant should generate a particular record.
 *
 * The default key ({@link XFTY_LookupKey}) is just an `SObjectType`, reproducing
 * the original one-Provider-per-type behaviour. Refined keys add a discriminator:
 * a record type ({@link XFTY_RecordTypeLookupKey}), or a record type plus
 * arbitrary predicates on the record ({@link XFTY_FlavouredLookupKey}), or a
 * custom implementation.
 *
 * A single record can match several registered keys, so
 * `XFTY_DummySObjectProviderLookupIntf.keysFor(...)` returns a `Set`; the most
 * specific match (`getSpecificity()`) wins.
 *
 * Keys are stored by `getHashKey()` rather than by object identity, so two
 * different instances describing the same variant resolve to the same Provider.
 */
public interface XFTY_LookupKeyIntf {
    /** The SObject type this key selects a Provider for. */
    SObjectType getSObjectType();

    /**
     * Whether `sObj` belongs to the variant this key describes. Used to derive a
     * key from a relationship's override template when none was supplied
     * explicitly.
     */
    Boolean isInstanceOf(SObject sObj);

    /** Value-equality identity. Two keys with the same hash key are the same key. */
    String getHashKey();

    /**
     * How specific this key is; higher wins when several keys match one record.
     * Plain type key = 0, record-type key = 10, flavoured key = 20+.
     */
    Integer getSpecificity();
}
