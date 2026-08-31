/**
 * `XFTY_DepthBatchedInserter` - one `insert` per dependency layer, of any mix of
 * types. Each test pins the DML-statement count, not just the wiring.
 *
 * Real DML, so `XFTY_Integration`.
 */
@IsTest
private class XFTY_DepthBatchedInserterTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void nullInputDoesNothing() {
        Assert.areEqual(0, insertCountingDml(null, null));
    }

    @IsTest
    static void emptyInputDoesNothing() {
        Assert.areEqual(0, insertCountingDml(new List<SObject>(), links()));
    }

    @IsTest
    static void independentRecordsInsertInOneStatement() {
        List<SObject> records = new List<SObject>{
                new Account(Name = 'A'), new Account(Name = 'B'), new Account(Name = 'C')
        };

        Assert.areEqual(1, insertCountingDml(records, null));
        Assert.isNotNull(records[2].Id);
    }

    @IsTest
    static void aParentInsertsBeforeItsChildAndTheLookupIsPointed() {
        Account parentCo = new Account(Name = 'Parent Co');
        Contact childCon = new Contact(LastName = 'Child');
        List<SObject> records = new List<SObject>{ childCon, parentCo };

        Integer dml = insertCountingDml(records, links(link(0, 1, Contact.AccountId)));

        Assert.areEqual(2, dml);
        Assert.areEqual(parentCo.Id, childCon.AccountId);
    }

    @IsTest
    static void parentsOfDifferentTypesShareOneInsert() {
        Account whatCo = new Account(Name = 'What Co');
        Contact whoCon = new Contact(LastName = 'Who');
        Task callTask = new Task(Subject = 'Call');
        List<SObject> records = new List<SObject>{ callTask, whatCo, whoCon };

        Integer dml = insertCountingDml(
                records, links(link(0, 1, Task.WhatId), link(0, 2, Task.WhoId))
        );

        Assert.areEqual(2, dml, 'both parents at layer 0, Task alone at layer 1');
        Assert.areEqual(whatCo.Id, callTask.WhatId);
        Assert.areEqual(whoCon.Id, callTask.WhoId);
    }

    @IsTest
    static void aChainCostsOneInsertPerLink() {
        Account gen1 = new Account(Name = 'Gen 1');
        Contact gen2 = new Contact(LastName = 'Gen 2');
        Contact gen3 = new Contact(LastName = 'Gen 3');
        List<SObject> records = new List<SObject>{ gen1, gen2, gen3 };

        Integer dml = insertCountingDml(
                records, links(link(1, 0, Contact.AccountId), link(2, 1, Contact.ReportsToId))
        );

        Assert.areEqual(3, dml);
        Assert.areEqual(gen1.Id, gen2.AccountId);
        Assert.areEqual(gen2.Id, gen3.ReportsToId);
    }

    @IsTest
    static void oneParentSharedByTwoChildrenInsertsOnce() {
        Account parentCo = new Account(Name = 'Shared');
        Contact first = new Contact(LastName = 'First');
        Contact second = new Contact(LastName = 'Second');
        List<SObject> records = new List<SObject>{ parentCo, first, second };

        Integer dml = insertCountingDml(
                records, links(link(1, 0, Contact.AccountId), link(2, 0, Contact.AccountId))
        );

        Assert.areEqual(2, dml);
        Assert.areEqual(parentCo.Id, first.AccountId);
        Assert.areEqual(parentCo.Id, second.AccountId);
    }

    @IsTest
    static void aCycleThrows() {
        List<SObject> records = new List<SObject>{ new Account(Name = 'A'), new Account(Name = 'B') };
        assertCyclic(records, links(link(0, 1, Account.ParentId), link(1, 0, Account.ParentId)));
    }

    @IsTest
    static void aSelfReferenceThrows() {
        assertCyclic(new List<SObject>{ new Account(Name = 'Loop') }, links(link(0, 0, Account.ParentId)));
    }

    // helpers ------------------------------------------------------------------

    private static XFTY_DepthBatchedInserter.ParentLink link(Integer child, Integer parent, SObjectField field) {
        return new XFTY_DepthBatchedInserter.ParentLink(child, parent, field);
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

    private static List<XFTY_DepthBatchedInserter.ParentLink> links() {
        return new List<XFTY_DepthBatchedInserter.ParentLink>();
    }

    private static Integer insertCountingDml(
            List<SObject> records,
            List<XFTY_DepthBatchedInserter.ParentLink> links
    ) {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DepthBatchedInserter.insertAll(records, links);
            dml = Limits.getDmlStatements() - before;
        }
        return dml;
    }

    private static void assertCyclic(
            List<SObject> records,
            List<XFTY_DepthBatchedInserter.ParentLink> links
    ) {
        try {
            System.runAs(TEST_ADMIN) {
                XFTY_DepthBatchedInserter.insertAll(records, links);
            }
            Assert.fail('Expected a CyclicGraphException');
        } catch (XFTY_DepthBatchedInserter.CyclicGraphException ex) {
            Assert.isTrue(ex.getMessage().contains('cycle'), ex.getMessage());
        }
    }
}
