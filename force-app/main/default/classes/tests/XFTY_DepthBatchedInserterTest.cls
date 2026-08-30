/**
 * Branch coverage for `XFTY_DepthBatchedInserter` - the mixed-type,
 * one-insert-per-depth persistence helper.
 *
 * Real DML, so `XFTY_Integration`. Runs inside `System.runAs` and measures the
 * DML-statement delta so the batching claims are actually pinned, not just the
 * wiring.
 */
@IsTest
private class XFTY_DepthBatchedInserterTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void nullRecordsIsANoOp() {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(null, null);
            dml = Limits.getDmlStatements() - before;
        }
        Assert.areEqual(0, dml, 'a null record set must not touch the database');
    }

    @IsTest
    static void emptyRecordsIsANoOp() {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(new List<SObject>(), new List<XFTY_DepthBatchedInserter.Edge>());
            dml = Limits.getDmlStatements() - before;
        }
        Assert.areEqual(0, dml, 'an empty record set must not touch the database');
    }

    @IsTest
    static void aFlatSetWithNoEdgesInsertsInOneStatement() {
        List<SObject> records = new List<SObject>{
                new Account(Name = 'Flat A'),
                new Account(Name = 'Flat B'),
                new Account(Name = 'Flat C')
        };
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, null);
            dml = Limits.getDmlStatements() - before;
        }

        Assert.areEqual(1, dml, 'no dependencies => one insert');
        for (SObject record : records) {
            Assert.isNotNull(record.Id, 'every record is inserted and its Id is on the handed-in instance');
        }
    }

    @IsTest
    static void aTwoLevelGraphInsertsTheParentFirstAndWiresTheLookup() {
        Account parentCo = new Account(Name = 'Parent Co');
        Contact childCon = new Contact(LastName = 'Child');
        List<SObject> records = new List<SObject>{ childCon, parentCo }; // child listed first on purpose
        List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>{
                new XFTY_DepthBatchedInserter.Edge(0, 1, Contact.AccountId)
        };

        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, edges);
            dml = Limits.getDmlStatements() - before;
        }

        Assert.areEqual(2, dml, 'one insert per level');
        Assert.isNotNull(parentCo.Id);
        Assert.areEqual(parentCo.Id, childCon.AccountId, 'the child lookup is re-pointed to the fresh parent Id');
    }

    @IsTest
    static void mixedTypesAtTheSameDepthShareOneInsert() {
        Account whatCo = new Account(Name = 'What Co');
        Contact whoCon = new Contact(LastName = 'Who');
        Task callTask = new Task(Subject = 'Call');
        List<SObject> records = new List<SObject>{ callTask, whatCo, whoCon };
        List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>{
                new XFTY_DepthBatchedInserter.Edge(0, 1, Task.WhatId),
                new XFTY_DepthBatchedInserter.Edge(0, 2, Task.WhoId)
        };

        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, edges);
            dml = Limits.getDmlStatements() - before;
        }

        Assert.areEqual(2, dml, 'Account + Contact batch together at depth 0; Task alone at depth 1');
        Assert.areEqual(whatCo.Id, callTask.WhatId);
        Assert.areEqual(whoCon.Id, callTask.WhoId);
    }

    @IsTest
    static void aDeepChainCostsOneInsertPerLevel() {
        Account grandparent = new Account(Name = 'Gen 1');
        Contact parent = new Contact(LastName = 'Gen 2');
        Contact child = new Contact(LastName = 'Gen 3');
        List<SObject> records = new List<SObject>{ grandparent, parent, child };
        List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>{
                new XFTY_DepthBatchedInserter.Edge(1, 0, Contact.AccountId),
                new XFTY_DepthBatchedInserter.Edge(2, 1, Contact.ReportsToId)
        };

        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, edges);
            dml = Limits.getDmlStatements() - before;
        }

        Assert.areEqual(3, dml, 'three levels => three inserts');
        Assert.areEqual(grandparent.Id, parent.AccountId);
        Assert.areEqual(parent.Id, child.ReportsToId);
    }

    @IsTest
    static void aRelatedSourceFieldWiresFromANonIdField() {
        Account parent = new Account(Name = 'Source Name Co');
        Account child = new Account(Name = 'Child Co');
        List<SObject> records = new List<SObject>{ parent, child };
        List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>{
                new XFTY_DepthBatchedInserter.Edge(1, 0, Account.Description, Account.Name)
        };

        System.runAs(TEST_ADMIN) {
            XFTY_DepthBatchedInserter.insertAll(records, edges);
        }

        Assert.areEqual('Source Name Co', child.Description, 'wired from the parent Name, not its Id');
    }

    @IsTest
    static void aTwoRecordCycleThrows() {
        List<SObject> records = new List<SObject>{
                new Account(Name = 'Loop A'),
                new Account(Name = 'Loop B')
        };
        List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>{
                new XFTY_DepthBatchedInserter.Edge(0, 1, Account.ParentId),
                new XFTY_DepthBatchedInserter.Edge(1, 0, Account.ParentId)
        };

        try {
            System.runAs(TEST_ADMIN) {
                XFTY_DepthBatchedInserter.insertAll(records, edges);
            }
            Assert.fail('Expected a CyclicGraphException');
        } catch (XFTY_DepthBatchedInserter.CyclicGraphException ex) {
            Assert.isTrue(ex.getMessage().contains('cycle'), ex.getMessage());
        }
    }

    @IsTest
    static void aSelfReferenceThrows() {
        List<SObject> records = new List<SObject>{ new Account(Name = 'Ouroboros') };
        List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>{
                new XFTY_DepthBatchedInserter.Edge(0, 0, Account.ParentId)
        };

        try {
            System.runAs(TEST_ADMIN) {
                XFTY_DepthBatchedInserter.insertAll(records, edges);
            }
            Assert.fail('Expected a CyclicGraphException');
        } catch (XFTY_DepthBatchedInserter.CyclicGraphException ex) {
            Assert.isTrue(ex.getMessage().contains('cycle'), ex.getMessage());
        }
    }

    @IsTest
    static void aSharedParentReferencedByTwoChildrenIsInsertedOnce() {
        Account shared = new Account(Name = 'Shared Parent');
        Contact first = new Contact(LastName = 'First');
        Contact second = new Contact(LastName = 'Second');
        List<SObject> records = new List<SObject>{ shared, first, second };
        List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>{
                new XFTY_DepthBatchedInserter.Edge(1, 0, Contact.AccountId),
                new XFTY_DepthBatchedInserter.Edge(2, 0, Contact.AccountId)
        };

        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, edges);
            dml = Limits.getDmlStatements() - before;
        }

        Assert.areEqual(2, dml, 'the shared parent inserts once at depth 0; both children at depth 1');
        Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Name = 'Shared Parent']);
        Assert.areEqual(shared.Id, first.AccountId);
        Assert.areEqual(shared.Id, second.AccountId);
    }
}
