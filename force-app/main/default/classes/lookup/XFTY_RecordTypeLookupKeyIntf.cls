/**
 * A lookup key that carries a record type, so the lookup can report the record
 * type a variant is for without caring whether it is a plain
 * {@link XFTY_RecordTypeLookupKey} or a {@link XFTY_FlavouredLookupKey}.
 */
public interface XFTY_RecordTypeLookupKeyIntf extends XFTY_LookupKeyIntf {
    /** The record type developer name, or null if this key is not record-type specific. */
    String getRecordTypeDeveloperName();

    /** The matching record type Id (resolved from the describe), or null. */
    Id getRecordTypeId();
}
