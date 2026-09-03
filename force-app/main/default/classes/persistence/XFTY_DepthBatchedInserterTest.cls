/**
 * Proves `XFTY_DepthBatchedInserter.insertAll` - one `insert` per dependency
 * layer, of any mix of types. Each test pins the DML-statement count, not just
 * the wiring. Real DML, so `System.runAs`.
 */
@IsTest
private class XFTY_DepthBatchedInserterTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testInsertAll_forNullInput_doesNothing() {
        assertInsertCount(null, null, 0);
    }

    @IsTest
    static void testInsertAll_forEmptyInput_doesNothing() {
        assertInsertCount(new List<SObject>(), links(), 0);
    }

    @IsTest
    static void testInsertAll_forIndependentRecords_insertsThemInOneStatement() {
        // Arrange
        List<SObject> records = new List<SObject>{
                new Account(Name = 'A'), new Account(Name = 'B'), new Account(Name = 'C')
        };

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, null);
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, dml);
        Assert.isNotNull(records[2].Id);
    }

    @IsTest
    static void testInsertAll_forAParentAndChild_insertsTheParentFirstAndPointsTheLookup() {
        // Arrange
        Account parent = new Account(Name = 'Parent Co');
        Contact child = new Contact(LastName = 'Child');
        List<SObject> records = new List<SObject>{ child, parent };

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, links(link(0, 1, Contact.AccountId)));
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, dml);
        Assert.areEqual(parent.Id, child.AccountId);
    }

    @IsTest
    static void testInsertAll_forParentsOfDifferentTypes_sharesOneInsert() {
        // Arrange
        Account whatCo = new Account(Name = 'What Co');
        Contact whoCon = new Contact(LastName = 'Who');
        Task callTask = new Task(Subject = 'Call');
        List<SObject> records = new List<SObject>{ callTask, whatCo, whoCon };

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, links(link(0, 1, Task.WhatId), link(0, 2, Task.WhoId)));
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, dml, 'both parents at layer 0, Task alone at layer 1');
        Assert.areEqual(whatCo.Id, callTask.WhatId);
        Assert.areEqual(whoCon.Id, callTask.WhoId);
    }

    @IsTest
    static void testInsertAll_forAChain_costsOneInsertPerLink() {
        // Arrange
        Account gen1 = new Account(Name = 'Gen 1');
        Contact gen2 = new Contact(LastName = 'Gen 2');
        Contact gen3 = new Contact(LastName = 'Gen 3');
        List<SObject> records = new List<SObject>{ gen1, gen2, gen3 };

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, links(link(1, 0, Contact.AccountId), link(2, 1, Contact.ReportsToId)));
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(3, dml);
        Assert.areEqual(gen1.Id, gen2.AccountId);
        Assert.areEqual(gen2.Id, gen3.ReportsToId);
    }

    @IsTest
    static void testInsertAll_forOneParentSharedByTwoChildren_insertsTheParentOnce() {
        // Arrange
        Account parent = new Account(Name = 'Shared');
        Contact first = new Contact(LastName = 'First');
        Contact second = new Contact(LastName = 'Second');
        List<SObject> records = new List<SObject>{ parent, first, second };

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, links(link(1, 0, Contact.AccountId), link(2, 0, Contact.AccountId)));
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, dml);
        Assert.areEqual(parent.Id, first.AccountId);
        Assert.areEqual(parent.Id, second.AccountId);
    }

    @IsTest
    static void testInsertAll_whenTwoRecordsReferenceEachOther_throws() {
        assertCyclic(
                new List<SObject>{ new Account(Name = 'A'), new Account(Name = 'B') },
                links(link(0, 1, Account.ParentId), link(1, 0, Account.ParentId))
        );
    }

    @IsTest
    static void testInsertAll_whenARecordReferencesItself_throws() {
        assertCyclic(new List<SObject>{ new Account(Name = 'Loop') }, links(link(0, 0, Account.ParentId)));
    }

    @IsTest
    static void testSeedAll_forEmptyInput_returnsAnEmptyMap() {
        // Arrange - nothing to seed

        // Act
        Map<Integer, Database.SaveResult> outcomes;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            outcomes = XFTY_DepthBatchedInserter.seedAll(new List<SObject>(), links());
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, outcomes.size());
    }

    @IsTest
    static void testSeedAll_forAValidParentAndChild_savesBothAndWiresTheLookup() {
        // Arrange
        Contact child = new Contact(LastName = 'Child');
        Account parent = new Account(Name = 'Parent Co');
        List<SObject> records = new List<SObject>{ child, parent };

        // Act
        Map<Integer, Database.SaveResult> outcomes;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            outcomes = XFTY_DepthBatchedInserter.seedAll(records, links(link(0, 1, Contact.AccountId)));
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(outcomes.get(0).isSuccess() && outcomes.get(1).isSuccess());
        Assert.areEqual(parent.Id, child.AccountId);
    }

    @IsTest
    static void testSeedAll_whenOneRecordIsInvalid_savesTheRestAndReturnsBothOutcomes() {
        // Arrange - a Contact with no LastName cannot be inserted
        List<SObject> records = new List<SObject>{
                new Account(Name = 'Good'), new Contact()
        };

        // Act
        Map<Integer, Database.SaveResult> outcomes;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            outcomes = XFTY_DepthBatchedInserter.seedAll(records, links());
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(outcomes.get(0).isSuccess(), 'the valid record still landed');
        Assert.isFalse(outcomes.get(1).isSuccess(), 'the invalid record was reported, not thrown');
    }

    @IsTest
    static void testSeedAll_forAChain_savesEachLayerBeforeTheNext() {
        // Arrange - Account <- Contact <- Contact
        Account gen1 = new Account(Name = 'Chain 1');
        Contact gen2 = new Contact(LastName = 'Chain 2');
        Contact gen3 = new Contact(LastName = 'Chain 3');
        List<SObject> records = new List<SObject>{ gen1, gen2, gen3 };

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_DepthBatchedInserter.seedAll(records, links(link(1, 0, Contact.AccountId), link(2, 1, Contact.ReportsToId)));
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(gen1.Id, gen2.AccountId);
        Assert.areEqual(gen2.Id, gen3.ReportsToId);
    }

    @IsTest
    static void testSeedAll_whenAParentIsRejected_theChildIsStillAttemptedWithoutIt() {
        // Arrange - the parent Account has no Name; the child Contact links to it
        Account badParent = new Account();
        Contact child = new Contact(LastName = 'Orphaned');
        List<SObject> records = new List<SObject>{ badParent, child };

        // Act
        Map<Integer, Database.SaveResult> outcomes;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            outcomes = XFTY_DepthBatchedInserter.seedAll(records, links(link(1, 0, Contact.AccountId)));
            Test.stopTest();
        }

        // Assert
        Assert.isFalse(outcomes.get(0).isSuccess(), 'the parent was rejected');
        Assert.isTrue(outcomes.get(1).isSuccess(), 'the child still lands, just without the lookup');
        Assert.isNull(child.AccountId, 'no parent Id to point at');
    }

    @IsTest
    static void testSeedAll_forACyclicGraph_stillThrows() {
        // Arrange - best effort covers row failures, not an impossible insert order
        List<SObject> records = new List<SObject>{ new Account(Name = 'A'), new Account(Name = 'B') };

        // Act
        XFTY_DepthBatchedInserter.CyclicGraphException thrown;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            try {
                XFTY_DepthBatchedInserter.seedAll(records, links(link(0, 1, Account.ParentId), link(1, 0, Account.ParentId)));
            } catch (XFTY_DepthBatchedInserter.CyclicGraphException ex) {
                thrown = ex;
            }
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(thrown);
    }

    // Runners + helpers -------------------------------------

    static void assertInsertCount(
            List<SObject> records,
            List<XFTY_DepthBatchedInserter.ParentLink> parentLinks,
            Integer expectedDml
    ) {
        // Arrange - the caller supplies the records and links

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, parentLinks);
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(expectedDml, dml);
    }

    static void assertCyclic(List<SObject> records, List<XFTY_DepthBatchedInserter.ParentLink> parentLinks) {
        // Arrange - the caller supplies a cyclic graph

        // Act
        XFTY_DepthBatchedInserter.CyclicGraphException thrown;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            try {
                XFTY_DepthBatchedInserter.insertAll(records, parentLinks);
            } catch (XFTY_DepthBatchedInserter.CyclicGraphException ex) {
                thrown = ex;
            }
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(thrown, 'a cyclic graph must be rejected');
        Assert.isTrue(thrown.getMessage().contains('cycle'), thrown.getMessage());
    }

    private static XFTY_DepthBatchedInserter.ParentLink link(Integer child, Integer parent, SObjectField field) {
        return new XFTY_DepthBatchedInserter.ParentLink(child, parent, field);
    }

    private static List<XFTY_DepthBatchedInserter.ParentLink> links() {
        return new List<XFTY_DepthBatchedInserter.ParentLink>();
    }

    private static List<XFTY_DepthBatchedInserter.ParentLink> links(XFTY_DepthBatchedInserter.ParentLink link1) {
        return new List<XFTY_DepthBatchedInserter.ParentLink>{ link1 };
    }

    private static List<XFTY_DepthBatchedInserter.ParentLink> links(
            XFTY_DepthBatchedInserter.ParentLink link1,
            XFTY_DepthBatchedInserter.ParentLink link2
    ) {
        return new List<XFTY_DepthBatchedInserter.ParentLink>{ link1, link2 };
    }
}
