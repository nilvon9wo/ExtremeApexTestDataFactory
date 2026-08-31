/** An SObject paired with its position in the list or pass that is working on it. */
@IsTest
public class XFTY_IndexedRecord {

    public final Integer index;
    public final SObject record;

    public XFTY_IndexedRecord(Integer index, SObject record) {
        this.index = index;
        this.record = record;
    }
}
