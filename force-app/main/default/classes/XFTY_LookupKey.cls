/**
 * The default lookup key: an `SObjectType` and nothing else.
 *
 * Using only this key reproduces XFTY's original behaviour - exactly one Provider
 * per SObject type.
 *
 * Instances are flyweights - obtain them with `XFTY_LookupKey.get(...)`, never
 * `new` (the constructor is private). Refined keys
 * ({@link XFTY_RecordTypeLookupKey}, {@link XFTY_FlavouredLookupKey}, or your own)
 * *compose* an `XFTY_LookupKey` rather than extend it (`@IsTest` classes cannot
 * be virtual).
 */
@IsTest
public class XFTY_LookupKey implements XFTY_LookupKeyIntf {
    private static final Map<SObjectType, XFTY_LookupKey> INSTANCE_BY_TYPE
            = new Map<SObjectType, XFTY_LookupKey>();

    private final SObjectType sObjectType;

    private XFTY_LookupKey(SObjectType sObjectType) {
        this.sObjectType = sObjectType;
    }

    public static XFTY_LookupKey get(SObjectType sObjectType) {
        if (sObjectType == null) {
            throw new XFTY_DummySObjectFtyProviderException('A lookup key requires an SObjectType.');
        }
        if (!INSTANCE_BY_TYPE.containsKey(sObjectType)) {
            INSTANCE_BY_TYPE.put(sObjectType, new XFTY_LookupKey(sObjectType));
        }
        return INSTANCE_BY_TYPE.get(sObjectType);
    }

    public static XFTY_LookupKey get(SObject sObj) {
        return get(sObj == null ? null : sObj.getSObjectType());
    }

    public SObjectType getSObjectType() {
        return this.sObjectType;
    }

    public Boolean isInstanceOf(SObject sObj) {
        return sObj != null && sObj.getSObjectType() == this.sObjectType;
    }

    public String getHashKey() {
        return String.valueOf(this.sObjectType);
    }

    public Integer getSpecificity() {
        return 0;
    }

    // Value equality by hash key, so lookup keys work as Map keys directly.
    public Boolean equals(Object other) {
        return (other instanceof XFTY_LookupKeyIntf)
                && ((XFTY_LookupKeyIntf) other).getHashKey() == this.getHashKey();
    }

    public Integer hashCode() {
        return this.getHashKey().hashCode();
    }
}
