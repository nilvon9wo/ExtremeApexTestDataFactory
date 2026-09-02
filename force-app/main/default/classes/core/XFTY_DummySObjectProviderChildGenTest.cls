/**
 * Proves downward generation - `XFTY_DummySObjectProvider.with(...)` /
 * `withChildren(...)` / `withChild(...)` and `XFTY_SObjectChildProvider`. Tests
 * that touch the database (NOW / DEFERRED / depth-batched) run under
 * `System.runAs`; MOCK-only tests do not.
 */
@IsTest
private class XFTY_DummySObjectProviderChildGenTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    private static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                XFTY_LookupKey.get(Case.SObjectType) => new CaseProvider()
        });
    }

    // Shortcuts -----------------------------------------------------

    @IsTest
    static void testWithChildren_generatesNChildrenPerPrimaryEachPointingAtItsParent() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 3);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Id accountId = bundle.primaryRecords()[0].Id;
        List<SObject> contacts = bundle.getChildList(Contact.AccountId);
        Assert.areEqual(3, contacts.size());
        for (SObject contactRecord : contacts) {
            Assert.areEqual(accountId, ((Contact) contactRecord).AccountId);
            Assert.isNotNull(contactRecord.Id);
        }
    }

    @IsTest
    static void testWithChild_generatesExactlyOneChild() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChild(Contact.AccountId);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getChildList(Contact.AccountId).size());
        Assert.isNotNull(bundle.getChild(Contact.AccountId));
    }

    @IsTest
    static void testConstructor_derivesTheChildTypeFromTheRelationshipField() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_SObjectChildProvider childProvider = new XFTY_SObjectChildProvider(Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(Contact.SObjectType, childProvider.childType);
        Assert.areEqual(Contact.AccountId, childProvider.relationshipField);
    }

    // Templates + multiple configs ----------------------------

    @IsTest
    static void testWith_aChildProviderTemplate_appliesToEveryChild() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'Buying')).setQuantity(2));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        List<SObject> children = bundle.getChildList(Contact.AccountId);
        Assert.areEqual(2, children.size());
        for (SObject childContact : children) {
            Assert.areEqual('Buying', ((Contact) childContact).Department);
        }
    }

    @IsTest
    static void testWith_twoConfigsOnTheSameField_areAdditiveAndMultiplyWithTemplateQuantity() {
        // Arrange - the child-records.md worked example: 2 templates x setQuantityPerTemplate(4) = 8 primaries;
        // config A: 3 per primary -> 24 ; config B: 2 per primary -> 16 ; total 40.
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setOverrideTemplateList(new List<Account>{ new Account(), new Account() })
                .setQuantityPerTemplate(4)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'A')).setQuantity(3))
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'B')).setQuantity(2));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        List<SObject> childContacts = bundle.getChildList(Contact.AccountId);
        Integer departmentACount = 0;
        for (SObject childContact : childContacts) {
            if (((Contact) childContact).Department == 'A') {
                departmentACount++;
            }
        }
        Assert.areEqual(8, bundle.primaryRecords().size());
        Assert.areEqual(40, childContacts.size());
        Assert.areEqual(24, departmentACount);
        Assert.areEqual(16, childContacts.size() - departmentACount);
    }

    @IsTest
    static void testGetChildList_orderIsConfigThenPrimaryThenQuantity() {
        // Arrange - 2 primaries, config A (q2) then config B (q1):
        // A/P0, A/P0, A/P1, A/P1, B/P0, B/P1
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setQuantityPerTemplate(2)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'A')).setQuantity(2))
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'B')).setQuantity(1));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Id parentZero = bundle.primaryRecords()[0].Id;
        Id parentOne = bundle.primaryRecords()[1].Id;
        List<Contact> children = (List<Contact>) bundle.getChildList(Contact.AccountId);
        Assert.areEqual(6, children.size());
        assertContact(children[0], 'A', parentZero);
        assertContact(children[1], 'A', parentZero);
        assertContact(children[2], 'A', parentOne);
        assertContact(children[3], 'A', parentOne);
        assertContact(children[4], 'B', parentZero);
        assertContact(children[5], 'B', parentOne);
    }

    // Several child types ------------------------------------

    @IsTest
    static void testWithChildren_forSeveralChildTypes_appliesThemConcurrently() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 2)
                .withChildren(Case.AccountId, 3);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(2, bundle.getChildList(Contact.AccountId).size());
        Assert.areEqual(3, bundle.getChildList(Case.AccountId).size());
        Assert.areEqual(2, bundle.childRelationshipFields().size());
    }

    // Children's own parents --------------------------------

    @IsTest
    static void testWith_atRequiredInclusivity_eachChildGeneratesItsOwnRequiredParent() {
        // Arrange - Account -> child Case (Case.AccountId) -> Case's own required Contact -> that Contact's Account
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .with(new XFTY_SObjectChildProvider(Case.AccountId).setQuantity(2));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Id rootAccountId = bundle.primaryRecords()[0].Id;
        XFTY_DummySObjectBundle caseBundle = bundle.getChildBundle(Case.AccountId);
        Assert.areEqual(2, caseBundle.primaryRecords().size());
        for (SObject caseRecord : caseBundle.primaryRecords()) {
            Assert.areEqual(rootAccountId, ((Case) caseRecord).AccountId, 'root link');
            Assert.isNotNull(((Case) caseRecord).ContactId, 'own required Contact parent generated');
        }
        List<SObject> childContacts = caseBundle.getBundle(Case.ContactId).primaryRecords();
        Assert.areEqual(2, childContacts.size());
        for (SObject childContact : childContacts) {
            Assert.isNotNull(((Contact) childContact).AccountId);
            Assert.areNotEqual(rootAccountId, ((Contact) childContact).AccountId, 'a distinct Account, not the root');
        }
    }

    // Grandchildren -----------------------------------------

    @IsTest
    static void testWith_nestedChildProviders_generateGrandchildrenPointingAtTheirParent() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(3))
                );

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        List<SObject> contacts = bundle.getChildList(Contact.AccountId);
        Assert.areEqual(2, contacts.size());
        List<SObject> cases = bundle.getChildBundle(Contact.AccountId).getChildList(Case.ContactId);
        Assert.areEqual(6, cases.size(), '2 Contacts x 3 Cases');
        Set<Id> contactIds = new Map<Id, SObject>(contacts).keySet();
        for (SObject caseRecord : cases) {
            Assert.isTrue(contactIds.contains(((Case) caseRecord).ContactId), 'grandchild points at its Contact');
        }
    }

    @IsTest
    static void testFlush_inDeferredMode_insertsEveryLevelIncludingGrandchildren() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(2))
                );

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            provider.supplyBundle();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(2, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(4, [SELECT COUNT() FROM Case WHERE ContactId != null]);
        for (Contact contactRecord : [SELECT Id, (SELECT Id FROM Cases) FROM Contact]) {
            Assert.areEqual(2, contactRecord.Cases.size());
        }
    }

    // Sanity guards -----------------------------------------

    @IsTest
    static void testWith_whenTheNestedRelationshipFieldDoesNotPointAtTheChildType_throws() {
        // Arrange - Contact.AccountId points at Account, not Contact
        XFTY_SObjectChildProvider parentChild = new XFTY_SObjectChildProvider(Contact.AccountId);

        // Act
        Exception thrown;
        Test.startTest();
        try {
            parentChild.with(new XFTY_SObjectChildProvider(Contact.AccountId));
        } catch (Exception ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('points at'), thrown.getMessage());
    }

    @IsTest
    static void testWith_whenTheTopLevelRelationshipFieldDoesNotPointAtTheProviderType_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup());

        // Act
        Exception thrown;
        Test.startTest();
        try {
            provider.with(new XFTY_SObjectChildProvider(Case.AccountId));
        } catch (Exception ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('points at'), thrown.getMessage());
    }

    @IsTest
    static void testSetQuantity_belowOne_throws() {
        // Arrange
        XFTY_SObjectChildProvider childProvider = new XFTY_SObjectChildProvider(Contact.AccountId);

        // Act
        Exception thrown;
        Test.startTest();
        try {
            childProvider.setQuantity(0);
        } catch (Exception ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('at least 1'), thrown.getMessage());
    }

    // Deferred / depth-batched ----------------------------

    @IsTest
    static void testFlush_inDeferredMode_insertsChildrenWithTheParentsInOnePass() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setQuantityPerTemplate(2)
                .withChildren(Contact.AccountId, 3);

        // Act
        XFTY_DummySObjectBundle bundle;
        Integer accountsBeforeFlush;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            accountsBeforeFlush = [SELECT COUNT() FROM Account];
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, accountsBeforeFlush, 'nothing inserted before flush');
        Assert.areEqual(2, [SELECT COUNT() FROM Account]);
        Assert.areEqual(6, [SELECT COUNT() FROM Contact]);
        for (Account account : [SELECT Id, (SELECT Id FROM Contacts) FROM Account]) {
            Assert.areEqual(3, account.Contacts.size(), 'each parent got its 3 children, FK wired at flush');
        }
        Assert.isNotNull(bundle.getChildList(Contact.AccountId)[0].Id, 'child Id back-filled');
    }

    @IsTest
    static void testSupplyBundle_inDepthBatchedNowMode_insertsChildrenWithTheParents() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .depthBatched()
                .withChildren(Contact.AccountId, 2);

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(2, [SELECT COUNT() FROM Contact WHERE AccountId != null]);
    }

    @IsTest
    static void testSupplyBundle_whenTheParentIsDeferred_ignoresAChildInsertModeOverride() {
        // Arrange - under DEFERRED the whole subtree is structural; a child NOW override cannot opt out
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .with(new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2).setInsertMode(XFTY_InsertModeEnum.NOW));

        // Act
        Integer contactsBeforeFlush;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            provider.supplyBundle();
            contactsBeforeFlush = [SELECT COUNT() FROM Contact];
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, contactsBeforeFlush, 'the NOW override did not insert the children early');
        Assert.areEqual(2, [SELECT COUNT() FROM Contact], 'they went in with the rest of the graph at flush');
    }

    // Insert mode --------------------------------------

    @IsTest
    static void testWithChildren_byDefault_theChildInheritsTheParentInsertMode() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .withChildren(Contact.AccountId, 2);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        Id accountId = bundle.primaryRecords()[0].Id;
        Assert.areEqual(2, [SELECT COUNT() FROM Contact WHERE AccountId = :accountId]);
    }

    @IsTest
    static void testWith_aChildCanRaiseItsOwnInsertModeAboveTheParents() {
        // Arrange - parent NEVER (no DML), child NOW (real)
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId)
                                .setQuantity(2)
                                .setInsertMode(XFTY_InsertModeEnum.NOW)
                );

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.isNull(bundle.primaryRecords()[0].Id, 'parent not inserted');
        Assert.areEqual(2, [SELECT COUNT() FROM Contact], 'children inserted');
    }

    @IsTest
    static void testSupplyBundle_whenANowParentHasAMockChild_throws() {
        testMockRealMix(XFTY_InsertModeEnum.NOW, XFTY_InsertModeEnum.MOCK);
    }

    @IsTest
    static void testSupplyBundle_whenAMockParentHasANowChild_throws() {
        testMockRealMix(XFTY_InsertModeEnum.MOCK, XFTY_InsertModeEnum.NOW);
    }

    @IsTest
    static void testSupplyBundle_whenTheParentIsLater_leavesChildrenExactlyAsNeverWould() {
        // Arrange - LATER is NEVER-with-intent, all the way down
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.LATER)
                .withChildren(Contact.AccountId, 2);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        List<SObject> children = bundle.getChildList(Contact.AccountId);
        Assert.areEqual(2, children.size(), 'the children are still generated');
        Assert.isNull(children[0].Id, 'just not inserted');
        Assert.isNull(children[0].get(Contact.AccountId), 'and the back-reference is null - no parent Id to point at');
    }

    @IsTest
    static void testSupplyBundle_whenTheParentIsRelatedOnly_doesNotPersistItsChildren() {
        // Arrange - RELATED_ONLY does not insert the primaries, so from a child's point of
        // view there is no persisted parent and RELATED_ONLY flows down
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.RELATED_ONLY)
                .withChildren(Contact.AccountId, 2);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, bundle.getChildList(Contact.AccountId).size());
        Assert.isNull(bundle.getChildList(Contact.AccountId)[0].Id, 'children are not inserted');
        Assert.areEqual(0, [SELECT COUNT() FROM Contact], 'nothing at the child level reaches the database');
    }

    // Bundle getters ---------------------------------

    @IsTest
    static void testGetChildBundle_mergesConfigsAndStaysNavigable() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .with(new XFTY_SObjectChildProvider(Case.AccountId, new Case(Origin = 'Web')).setQuantity(1))
                .with(new XFTY_SObjectChildProvider(Case.AccountId, new Case(Origin = 'Phone')).setQuantity(1));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        XFTY_DummySObjectBundle merged = bundle.getChildBundle(Case.AccountId);
        Assert.areEqual(2, merged.primaryRecords().size());
        Assert.areEqual(2, merged.getBundle(Case.ContactId).primaryRecords().size(),
                'the Cases from both configs generated their own Contact parent');
    }

    // Runners + helpers ----------------------------

    static void testMockRealMix(XFTY_InsertModeEnum parentMode, XFTY_InsertModeEnum childMode) {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(parentMode)
                .with(new XFTY_SObjectChildProvider(Contact.AccountId).setInsertMode(childMode));

        // Act
        XFTY_SObjectChildProvider.SanityException thrown;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            try {
                provider.supplyBundle();
            } catch (XFTY_SObjectChildProvider.SanityException ex) {
                thrown = ex;
            }
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(thrown, 'a mock/real mix must throw');
        Assert.isTrue(thrown.getMessage().contains('mix mock'), thrown.getMessage());
    }

    private static void assertContact(Contact childContact, String department, Id accountId) {
        Assert.areEqual(department, childContact.Department);
        Assert.areEqual(accountId, childContact.AccountId);
    }

    // In-test Providers --------------------------

    /** Case that needs a Contact (which in turn needs its own Account). */
    private class CaseProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                .put(Case.Subject, new XFTY_IncrementingStringExpression('Case'))
                .putRequired(Case.ContactId, new XFTY_DummyDefaultRelationship(new Contact()));

        public SObjectField getPrimaryTargetField() {
            return Case.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }
}
