/**
 * Branch coverage for `XFTY_DeferredInsertBuffer` - the bundle-to-flat-graph
 * adapter behind `.depthBatched()`. The end-to-end behaviour is exercised in
 * `XFTY_DummySObjectFactoryDmlTest`; this class drives the walk directly with
 * hand-built bundles, including the defensive guards the engine never trips.
 *
 * Real DML, so `XFTY_Integration`.
 */
@IsTest
private class XFTY_DeferredInsertBufferTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void aNullBundleIsANoOp() {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsertBuffer.insertGraph(null);
            dml = Limits.getDmlStatements() - before;
        }
        Assert.areEqual(0, dml, 'a null bundle is a no-op, not a crash');
    }

    @IsTest
    static void anEmptyBundleInsertsNothing() {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsertBuffer.insertGraph(new XFTY_DummySObjectBundle());
            dml = Limits.getDmlStatements() - before;
        }
        Assert.areEqual(0, dml, 'a bundle with no primary target field is a no-op');
    }

    @IsTest
    static void aTwoLevelBundleInsertsParentThenChildAndWiresTheLookup() {
        Account parentCo = new Account(Name = 'Buffer Parent');
        Contact childCon = new Contact(LastName = 'Buffer Child');

        XFTY_DummySObjectBundle parentBundle = new XFTY_DummySObjectBundle();
        parentBundle.primaryTargetField = Account.Id;
        parentBundle.put(Account.Id, new List<SObject>{ parentCo });

        XFTY_DummySObjectBundle childBundle = new XFTY_DummySObjectBundle();
        childBundle.primaryTargetField = Contact.Id;
        childBundle.put(Contact.Id, new List<SObject>{ childCon });
        childBundle.put(Contact.AccountId, parentBundle);
        childBundle.put(Contact.AccountId, new List<SObject>{ parentCo });

        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsertBuffer.insertGraph(childBundle);
            dml = Limits.getDmlStatements() - before;
        }

        Assert.areEqual(2, dml, 'one insert per level');
        Assert.isNotNull(parentCo.Id);
        Assert.areEqual(parentCo.Id, childCon.AccountId, 'the child lookup is wired to the fresh parent Id');
    }

    @IsTest
    static void aRelationshipFieldWithNoSubBundleIsSkipped() {
        Account onlyRecord = new Account(Name = 'No Parent Bundle');

        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.primaryTargetField = Account.Id;
        bundle.put(Account.Id, new List<SObject>{ onlyRecord });
        // a relationship key whose sub-bundle is missing - the walk must not choke
        bundle.put(Account.ParentId, (XFTY_DummySObjectBundle) null);

        System.runAs(TEST_ADMIN) {
            XFTY_DeferredInsertBuffer.insertGraph(bundle);
        }

        Assert.isNotNull(onlyRecord.Id, 'the record is still inserted');
    }
}
