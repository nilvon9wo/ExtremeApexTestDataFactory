/**
 * Proves `XFTY_DeferredInsertBuffer.insertGraph` driven directly with hand-built
 * bundles, including the guards the engine never trips. End-to-end behaviour is
 * covered by `XFTY_DummySObjectFactoryDmlTest` / `XFTY_DeferredInsertTest`. Real
 * DML, so `System.runAs`.
 */
@IsTest
private class XFTY_DeferredInsertBufferTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testInsertGraph_forANullBundle_doesNothing() {
        assertInsertGraphDml(null, 0);
    }

    @IsTest
    static void testInsertGraph_forABundleWithNoPrimaryRecords_doesNothing() {
        assertInsertGraphDml(new XFTY_DummySObjectBundle(), 0);
    }

    @IsTest
    static void testInsertGraph_forAParentAndChild_insertsTheParentFirstAndPointsTheLookup() {
        // Arrange
        Account parent = new Account(Name = 'Buffer Parent');
        Contact child = new Contact(LastName = 'Buffer Child');
        XFTY_DummySObjectBundle childBundle = bundleOf(Contact.Id, child);
        childBundle.put(Contact.AccountId, bundleOf(Account.Id, parent));
        childBundle.put(Contact.AccountId, new List<SObject>{ parent });

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsertBuffer.insertGraph(childBundle);
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, dml, 'one insert for the parent, one for the child');
        Assert.areEqual(parent.Id, child.AccountId, 'the child lookup points at the fresh parent Id');
    }

    @IsTest
    static void testInsertGraph_whenAChildLookupIsAlreadySet_leavesItAlone() {
        // Arrange
        Account existing = new Account(Name = 'Already Linked');
        Account generatedParent = new Account(Name = 'Generated Parent');
        Contact child = new Contact(LastName = 'Pre Linked');
        XFTY_DummySObjectBundle childBundle = bundleOf(Contact.Id, child);
        childBundle.put(Contact.AccountId, bundleOf(Account.Id, generatedParent));
        childBundle.put(Contact.AccountId, new List<SObject>{ generatedParent });

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            insert existing;
            child.AccountId = existing.Id;
            XFTY_DeferredInsertBuffer.insertGraph(childBundle);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(existing.Id, child.AccountId, 'the pre-set lookup is not repointed');
        Assert.isNotNull(generatedParent.Id, 'the generated parent still inserts');
    }

    @IsTest
    static void testInsertGraph_whenARelationshipFieldHasNoSubBundle_skipsItAndStillInsertsThePrimary() {
        // Arrange
        Account onlyRecord = new Account(Name = 'No Parent Bundle');
        XFTY_DummySObjectBundle bundle = bundleOf(Account.Id, onlyRecord);
        bundle.put(Account.ParentId, (XFTY_DummySObjectBundle) null);

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_DeferredInsertBuffer.insertGraph(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(onlyRecord.Id);
    }

    @IsTest
    static void testInsertGraph_forOneParentSharedByManyChildren_pointsEveryChildAtIt() {
        // Arrange - a shared ancestor: 3 Contacts, one Account bundle
        Account sharedParent = new Account(Name = 'Shared Parent');
        List<SObject> contacts = new List<SObject>{
                new Contact(LastName = 'A'), new Contact(LastName = 'B'), new Contact(LastName = 'C')
        };
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.primaryTargetField = Contact.Id;
        bundle.put(Contact.Id, contacts);
        bundle.put(Contact.AccountId, bundleOf(Account.Id, sharedParent));
        bundle.put(Contact.AccountId, new List<SObject>{ sharedParent });

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            XFTY_DeferredInsertBuffer.insertGraph(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Name = 'Shared Parent'], 'inserted once');
        for (SObject contact : contacts) {
            Assert.areEqual(sharedParent.Id, contact.get('AccountId'));
        }
    }

    @IsTest
    static void testFlatten_returnsEveryRecordAndItsParentLink_withoutInserting() {
        // Arrange
        Account parent = new Account(Name = 'Flatten Parent');
        Contact child = new Contact(LastName = 'Flatten Child');
        XFTY_DummySObjectBundle childBundle = bundleOf(Contact.Id, child);
        childBundle.put(Contact.AccountId, bundleOf(Account.Id, parent));
        childBundle.put(Contact.AccountId, new List<SObject>{ parent });

        // Act
        Test.startTest();
        Integer before = Limits.getDmlStatements();
        XFTY_DeferredInsertBuffer graph = XFTY_DeferredInsertBuffer.flatten(childBundle);
        Integer dml = Limits.getDmlStatements() - before;
        Test.stopTest();

        // Assert
        Assert.areEqual(0, dml, 'flatten does not insert');
        Assert.areEqual(2, graph.records().size(), 'the child and its parent');
        Assert.areEqual(1, graph.parentLinks().size(), 'one lookup to wire');
        Assert.isNull(child.Id, 'nothing was persisted');
    }

    // Helpers -----------------------------------------------

    private static XFTY_DummySObjectBundle bundleOf(SObjectField primaryField, SObject record) {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.primaryTargetField = primaryField;
        bundle.put(primaryField, new List<SObject>{ record });
        return bundle;
    }

    static void assertInsertGraphDml(XFTY_DummySObjectBundle bundle, Integer expectedDml) {
        // Arrange - the caller supplies the bundle

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            XFTY_DeferredInsertBuffer.insertGraph(bundle);
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(expectedDml, dml);
    }
}
