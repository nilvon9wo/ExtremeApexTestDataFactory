/**
 * Identifies which Provider variant should generate a particular record.
 *
 * The default key ({@link XFTY_LookupKey}) is just an `SObjectType`, reproducing
 * the original one-Provider-per-type behaviour. Refined keys add a discriminator
 * - a record type ({@link XFTY_RecordTypeLookupKey}), a developer-chosen flavor
 * ({@link XFTY_FlavorLookupKey}), or a custom subclass.
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
     * explicitly. A key whose discriminator cannot be read from a record (e.g. a
     * flavor) should return `false`.
     */
    Boolean isInstanceOf(SObject sObj);

    /** Value-equality identity. Two keys with the same hash key are the same key. */
    String getHashKey();
}
