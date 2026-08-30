/** Deep clones of an SObject, preserving Id, timestamps, autonumbers and relationships. */
@IsTest
public class XFTY_RecordClones {

    public static SObject deepClone(SObject record) {
        return record.clone(true, true, true, true);
    }

    public static List<SObject> deepClone(SObject record, Integer quantity) {
        List<SObject> clones = new List<SObject>();
        for (Integer i = 0; i < quantity; i++) {
            SObject copy = deepClone(record);
            clones.add(copy);
        }
        return clones;
    }
}
