/**
 * `XFTY_DeferredInsertBuffer` driven directly with hand-built bundles, including
 * the guards the engine never trips. The end-to-end behaviour is covered by
 * `XFTY_DummySObjectFactoryDmlTest` and `XFTY_DeferredInsertTest`.
 *
 * Real DML, so `XFTY_Integration`.
 */
@IsTest
private class XFTY_DeferredInsertBufferTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void aNullBundleDoesNothing() {
        Assert.areEqual(0, insertCountingDml(null));
    }

    @IsTest
    static void aBundleWithNoPrimaryRecordsDoesNothing() {
        Assert.areEqual(0, insertCountingDml(new XFTY_DummySObjectBundle()));
    }

    @IsTest
    static void aParentBundleInsertsBeforeItsChildAndTheLookupIsPointed() {
        Account parentCo = new Account(Name = 'Buffer Parent');
        Contact childCon = new Contact(LastName = 'Buffer Child');

        Integer dml = insertCountingDml(childBundleWithParent(childCon, parentCo));

        Assert.areEqual(2, dml);
        Assert.areEqual(parentCo.Id, childCon.AccountId);
    }

    @IsTest
    static void aRelationshipFieldWithNoSubBundleIsSkipped() {
        Account onlyRecord = new Account(Name = 'No Parent Bundle');
        XFTY_DummySObjectBundle bundle = bundleOf(Account.Id, onlyRecord);
        bundle.put(Account.ParentId, (XFTY_DummySObjectBundle) null);

        insertCountingDml(bundle);

        Assert.isNotNull(onlyRecord.Id);
    }

    // helpers ------------------------------------------------------------------

    private static XFTY_DummySObjectBundle bundleOf(SObjectField primaryField, SObject record) {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.primaryTargetField = primaryField;
        bundle.put(primaryField, new List<SObject>{ record });
        return bundle;
    }

    private static XFTY_DummySObjectBundle childBundleWithParent(Contact childCon, Account parentCo) {
        XFTY_DummySObjectBundle childBundle = bundleOf(Contact.Id, childCon);
        childBundle.put(Contact.AccountId, bundleOf(Account.Id, parentCo));
        childBundle.put(Contact.AccountId, new List<SObject>{ parentCo });
        return childBundle;
    }

    private static Integer insertCountingDml(XFTY_DummySObjectBundle bundle) {
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsertBuffer.insertGraph(bundle);
            dml = Limits.getDmlStatements() - before;
        }
        return dml;
    }
}
