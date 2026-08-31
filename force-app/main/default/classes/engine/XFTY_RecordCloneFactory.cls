/**
 * Creates full-fidelity in-memory copies of an SObject - keeping the Id, the
 * system timestamps, the autonumber values, and any populated child relationships
 * - so a copy stands in for the original everywhere a test looks.
 */
@IsTest
public class XFTY_RecordCloneFactory {

    private static final Boolean KEEP_ID = true;
    private static final Boolean INCLUDE_RELATED_RECORDS = true;
    private static final Boolean KEEP_CREATED_AND_UPDATED_STAMPS = true;
    private static final Boolean KEEP_AUTONUMBER_VALUES = true;

    public static SObject deepClone(SObject record) {
        return record.clone(
                KEEP_ID,
                INCLUDE_RELATED_RECORDS,
                KEEP_CREATED_AND_UPDATED_STAMPS,
                KEEP_AUTONUMBER_VALUES
        );
    }

    public static List<SObject> deepClones(SObject record, Integer quantity) {
        List<SObject> clones = new List<SObject>();
        for (Integer i = 0; i < quantity; i++) {
            SObject copy = deepClone(record);
            clones.add(copy);
        }
        return clones;
    }
}
