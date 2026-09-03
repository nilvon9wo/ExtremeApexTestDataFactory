/**
 * What `XFTY_Seeder.seed(bundle)` did: every record it sent to the database and
 * the `Database.SaveResult` the platform returned for it. Best effort, so a
 * partial result is normal - read `errors()` for the ones that did not land.
 *
 * A record that was already an anchor (a pre-set Id - e.g. a resolved shared
 * ancestor) is not re-inserted and does not appear in the counts.
 */
@IsTest
public class XFTY_SeedResult {

    private final List<SObject> graphRecords;
    private final Map<Integer, Database.SaveResult> outcomeByIndex;
    private final Boolean inIntegrationTest;

    public XFTY_SeedResult(
            List<SObject> graphRecords,
            Map<Integer, Database.SaveResult> outcomeByIndex,
            Boolean inIntegrationTest
    ) {
        this.graphRecords = graphRecords;
        this.outcomeByIndex = outcomeByIndex;
        this.inIntegrationTest = inIntegrationTest;
    }

    /**
     * Whether the seed ran inside an `@IntegrationTest` method - the only context
     * where the saved records outlive the transaction. `false` means the DML rolled
     * back and the counts below describe a run that left nothing behind.
     */
    public Boolean ranInIntegrationTest() {
        return this.inIntegrationTest;
    }

    /** How many records were sent to the database (the graph minus any anchors). */
    public Integer attemptedCount() {
        return this.outcomeByIndex.size();
    }

    public Integer savedCount() {
        return this.countWhereSuccess(true);
    }

    public Integer failedCount() {
        return this.countWhereSuccess(false);
    }

    public Boolean isFullySeeded() {
        return this.failedCount() == 0;
    }

    /** The saved records (Id populated), in graph order - what this run created, to undo it. */
    public List<SObject> savedRecords() {
        return this.recordsWhereSuccess(true);
    }

    /** The saved records of one type - e.g. `savedRecordsOfType(User.SObjectType)` to deactivate rather than delete. */
    public List<SObject> savedRecordsOfType(SObjectType type) {
        List<SObject> matching = new List<SObject>();
        for (SObject record : this.savedRecords()) {
            if (record.getSObjectType() == type) {
                matching.add(record);
            }
        }
        return matching;
    }

    /** The records the platform rejected, in graph order. */
    public List<SObject> failedRecords() {
        return this.recordsWhereSuccess(false);
    }

    /** One line per rejected record: its type and every status code + message. */
    public List<String> errors() {
        List<String> messages = new List<String>();
        for (Integer index : this.outcomeByIndex.keySet()) {
            Database.SaveResult outcome = this.outcomeByIndex.get(index);
            if (!outcome.isSuccess()) {
                messages.add(describe(this.graphRecords[index], outcome));
            }
        }
        return messages;
    }

    private Integer countWhereSuccess(Boolean success) {
        Integer count = 0;
        for (Database.SaveResult outcome : this.outcomeByIndex.values()) {
            if (outcome.isSuccess() == success) {
                count++;
            }
        }
        return count;
    }

    private List<SObject> recordsWhereSuccess(Boolean success) {
        List<SObject> matching = new List<SObject>();
        for (Integer index : this.outcomeByIndex.keySet()) {
            if (this.outcomeByIndex.get(index).isSuccess() == success) {
                matching.add(this.graphRecords[index]);
            }
        }
        return matching;
    }

    private static String describe(SObject record, Database.SaveResult outcome) {
        String detail = '';
        for (Database.Error error : outcome.getErrors()) {
            detail += (detail == '' ? '' : '; ') + error.getStatusCode() + ' ' + error.getMessage();
        }
        return record.getSObjectType() + ': ' + detail;
    }
}
