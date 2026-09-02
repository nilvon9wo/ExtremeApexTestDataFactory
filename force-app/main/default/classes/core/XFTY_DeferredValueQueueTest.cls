/**
 * Proves `XFTY_DeferredValueQueue` - collecting one pending value per primary row
 * per deferred field. Pure in-memory, no DML/SOQL. The strategy reference is
 * stored verbatim and never called here, so the tests pass `null` for it.
 */
@IsTest
private class XFTY_DeferredValueQueueTest {

    @IsTest
    static void testEntries_whenNothingWasAdded_isEmpty() {
        // Arrange
        XFTY_DeferredValueQueue queue = new XFTY_DeferredValueQueue();

        // Act
        Test.startTest();
        List<XFTY_DeferredValueQueue.Entry> entries = queue.entries();
        Test.stopTest();

        // Assert
        Assert.areEqual(0, entries.size());
    }

    @IsTest
    static void testAddForEachRow_always_queuesOneEntryPerRowPerField() {
        // Arrange
        XFTY_DeferredValueQueue queue = new XFTY_DeferredValueQueue();
        Map<SObjectField, XFTY_DeferredExpressionIntf> byField = new Map<SObjectField, XFTY_DeferredExpressionIntf>{
                Account.Name => null, Account.Site => null
        };

        // Act
        Test.startTest();
        queue.addForEachRow(3, byField);
        Test.stopTest();

        // Assert
        Assert.areEqual(6, queue.entries().size(), '3 rows x 2 fields');
    }

    @IsTest
    static void testAddForEachRow_whenRowCountIsZero_queuesNothing() {
        // Arrange
        XFTY_DeferredValueQueue queue = new XFTY_DeferredValueQueue();
        Map<SObjectField, XFTY_DeferredExpressionIntf> byField = new Map<SObjectField, XFTY_DeferredExpressionIntf>{
                Account.Name => null
        };

        // Act
        Test.startTest();
        queue.addForEachRow(0, byField);
        Test.stopTest();

        // Assert
        Assert.areEqual(0, queue.entries().size());
    }

    @IsTest
    static void testAddForEachRow_always_recordsTheRowAndFieldOnEachEntry() {
        // Arrange
        XFTY_DeferredValueQueue queue = new XFTY_DeferredValueQueue();
        Map<SObjectField, XFTY_DeferredExpressionIntf> byField = new Map<SObjectField, XFTY_DeferredExpressionIntf>{
                Account.Name => null
        };

        // Act
        Test.startTest();
        queue.addForEachRow(2, byField);
        Test.stopTest();

        // Assert
        List<XFTY_DeferredValueQueue.Entry> entries = queue.entries();
        Assert.areEqual(0, entries[0].primaryRow);
        Assert.areEqual(1, entries[1].primaryRow);
        Assert.areEqual(Account.Name, entries[1].field);
    }
}
