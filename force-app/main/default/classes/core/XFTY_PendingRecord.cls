/** A generated record waiting for a batched insert, and where it sits in the flat list. */
@IsTest
public class XFTY_PendingRecord {

    public final SObject record;
    public final Integer index;

    public XFTY_PendingRecord(SObject record, Integer index) {
        this.record = record;
        this.index = index;
    }
}
