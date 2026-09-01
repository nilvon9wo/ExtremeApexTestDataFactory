/**
 * Downward generation - `XFTY_DummySObjectProvider.with(...)` /
 * `withChildren(...)` / `withChild(...)` and `XFTY_SObjectChildProvider`.
 */
@IsTest
private class XFTY_ChildGenerationTest {
    private static final XFTY_DummySObjectProviderLookupIntf LOOKUP = new ChildTestLookup();

    // Shortcuts -------------------------------------------------------------------------

    @IsTest
    static void withChildrenShortcutGeneratesNPerPrimary() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();

        Id accountId = bundle.primaryRecords()[0].Id;
        List<SObject> contacts = bundle.getChildList(Contact.AccountId);
        System.assertEquals(3, contacts.size());
        for (SObject c : contacts) {
            System.assertEquals(accountId, ((Contact) c).AccountId);
            System.assertNotEquals(null, c.Id);
        }
    }

    @IsTest
    static void withChildShortcutGeneratesOne() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChild(Contact.AccountId)
                .supplyBundle();

        System.assertEquals(1, bundle.getChildList(Contact.AccountId).size());
        System.assertNotEquals(null, bundle.getChild(Contact.AccountId));
    }

    @IsTest
    static void childTypeIsDerivedFromTheRelationshipField() {
        XFTY_SObjectChildProvider childProvider = new XFTY_SObjectChildProvider(Contact.AccountId);
        System.assertEquals(Contact.SObjectType, childProvider.childType);
        System.assertEquals(Contact.AccountId, childProvider.relationshipField);
    }

    // Templates + multiple configs ----------------------------------------------------

    @IsTest
    static void templateOnTheChildProviderAppliesToEveryChild() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'Buying')).setQuantity(2))
                .supplyBundle();

        for (SObject c : bundle.getChildList(Contact.AccountId)) {
            System.assertEquals('Buying', ((Contact) c).Department);
        }
    }

    @IsTest
    static void twoConfigsOnTheSameFieldAreAdditiveAndMultiplyWithTemplateQuantity() {
        // Arrange - the child-records.md worked example: 2 templates x setQuantityPerTemplate(4) = 8 primaries;
        // config A: 3 per primary -> 24 ; config B: 2 per primary -> 16 ; total 40.
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setOverrideTemplateList(new List<Account>{ new Account(), new Account() })
                .setQuantityPerTemplate(4)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'A')).setQuantity(3))
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'B')).setQuantity(2));

        // Act
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();

        // Assert
        List<SObject> childContacts = bundle.getChildList(Contact.AccountId);
        Integer departmentACount = 0;
        Integer departmentBCount = 0;
        for (SObject childContact : childContacts) {
            if (((Contact) childContact).Department == 'A') {
                departmentACount++;
            } else {
                departmentBCount++;
            }
        }
        Assert.areEqual(8, bundle.primaryRecords().size());
        Assert.areEqual(40, childContacts.size());
        Assert.areEqual(24, departmentACount);
        Assert.areEqual(16, departmentBCount);
    }

    @IsTest
    static void getChildListOrderIsConfigThenPrimaryThenQuantity() {
        // 2 primaries, config A (q2) then config B (q1). Order:
        // A/P0, A/P0, A/P1, A/P1, B/P0, B/P1
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setQuantityPerTemplate(2)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'A')).setQuantity(2))
                .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department = 'B')).setQuantity(1))
                .supplyBundle();

        Id p0 = bundle.primaryRecords()[0].Id;
        Id p1 = bundle.primaryRecords()[1].Id;
        List<Contact> c = (List<Contact>) bundle.getChildList(Contact.AccountId);

        System.assertEquals(6, c.size());
        assertContact(c[0], 'A', p0);
        assertContact(c[1], 'A', p0);
        assertContact(c[2], 'A', p1);
        assertContact(c[3], 'A', p1);
        assertContact(c[4], 'B', p0);
        assertContact(c[5], 'B', p1);
    }

    private static void assertContact(Contact c, String dept, Id accountId) {
        System.assertEquals(dept, c.Department);
        System.assertEquals(accountId, c.AccountId);
    }

    // Several child types ------------------------------------------------------------

    @IsTest
    static void severalChildTypesApplyConcurrently() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 2)
                .withChildren(Case.AccountId, 3)
                .supplyBundle();

        System.assertEquals(2, bundle.getChildList(Contact.AccountId).size());
        System.assertEquals(3, bundle.getChildList(Case.AccountId).size());
        System.assertEquals(2, bundle.childRelationshipFields().size());
    }

    // Children's own parents --------------------------------------------------------

    @IsTest
    static void eachChildGeneratesItsOwnRequiredParent() {
        // Contact (child on Contact.AccountId, the "root" link) also needs its own
        // Account per the bundled Contact provider... but that IS AccountId, which is
        // the root link. Use Case -> requires ContactId -> Contact -> requires AccountId.
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .with(new XFTY_SObjectChildProvider(Case.AccountId).setQuantity(2))
                .supplyBundle();

        Id rootAccountId = bundle.primaryRecords()[0].Id;
        XFTY_DummySObjectBundle caseBundle = bundle.getChildBundle(Case.AccountId);
        System.assertEquals(2, caseBundle.primaryRecords().size());
        for (SObject c : caseBundle.primaryRecords()) {
            System.assertEquals(rootAccountId, ((Case) c).AccountId, 'root link');
            System.assertNotEquals(null, ((Case) c).ContactId, 'own required Contact parent generated');
        }
        // and that Contact generated its own Account (deeper ancestor)
        List<SObject> childContacts = caseBundle.getBundle(Case.ContactId).primaryRecords();
        System.assertEquals(2, childContacts.size());
        for (SObject cc : childContacts) {
            System.assertNotEquals(null, ((Contact) cc).AccountId);
            System.assertNotEquals(rootAccountId, ((Contact) cc).AccountId, 'a distinct Account, not the root');
        }
    }

    // Grandchildren ----------------------------------------------------------------

    @IsTest
    static void nestedChildProvidersGenerateGrandchildren() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(3))
                )
                .supplyBundle();

        List<SObject> contacts = bundle.getChildList(Contact.AccountId);
        System.assertEquals(2, contacts.size());

        XFTY_DummySObjectBundle contactBundle = bundle.getChildBundle(Contact.AccountId);
        List<SObject> cases = contactBundle.getChildList(Case.ContactId);
        System.assertEquals(6, cases.size(), '2 Contacts x 3 Cases');
        Set<Id> contactIds = new Map<Id, SObject>(contacts).keySet();
        for (SObject c : cases) {
            System.assert(contactIds.contains(((Case) c).ContactId), 'grandchild points at its Contact');
        }
    }

    @IsTest
    static void grandchildrenFlushWithEveryLevelInDeferredMode() {
        Test.startTest();
        new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(2))
                )
                .supplyBundle();
        XFTY_DeferredInserter.flush();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account]);
        System.assertEquals(2, [SELECT COUNT() FROM Contact]);
        System.assertEquals(4, [SELECT COUNT() FROM Case WHERE ContactId != null]);
        for (Contact c : [SELECT Id, (SELECT Id FROM Cases) FROM Contact]) {
            System.assertEquals(2, c.Cases.size());
        }
    }

    @IsTest
    static void nestedRelationshipFieldMustPointAtTheChildType() {
        try {
            new XFTY_SObjectChildProvider(Contact.AccountId)
                    .with(new XFTY_SObjectChildProvider(Contact.AccountId)); // Contact.AccountId -> Account, not Contact
            System.assert(false, 'expected a sanity exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('points at'), e.getMessage());
        }
    }

    @IsTest
    static void topLevelRelationshipFieldMustPointAtTheProviderType() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .with(new XFTY_SObjectChildProvider(Case.AccountId)); // Case.AccountId -> Account, provider is Contact
            System.assert(false, 'expected a sanity exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('points at'), e.getMessage());
        }
    }

    // Deferred / depth-batched ------------------------------------------------------

    @IsTest
    static void deferredModeInsertsChildrenWithTheParentsInOnePass() {
        Test.startTest();
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setQuantityPerTemplate(2)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();
        System.assertEquals(0, [SELECT COUNT() FROM Account], 'nothing inserted before flush');
        XFTY_DeferredInserter.flush();
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Account]);
        System.assertEquals(6, [SELECT COUNT() FROM Contact]);
        for (Account a : [SELECT Id, (SELECT Id FROM Contacts) FROM Account]) {
            System.assertEquals(3, a.Contacts.size(), 'each parent got its 3 children, FK wired at flush');
        }
        System.assertNotEquals(null, bundle.getChildList(Contact.AccountId)[0].Id, 'child Id back-filled');
    }

    @IsTest
    static void depthBatchedModeInsertsChildrenWithTheParents() {
        Test.startTest();
        new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .depthBatched()
                .withChildren(Contact.AccountId, 2)
                .supplyBundle();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account]);
        System.assertEquals(2, [SELECT COUNT() FROM Contact WHERE AccountId != null]);
    }

    // Insert mode --------------------------------------------------------------------

    @IsTest
    static void childInheritsTheParentInsertModeByDefault() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .withChildren(Contact.AccountId, 2)
                .supplyBundle();
        Id accountId = bundle.primaryRecords()[0].Id;
        System.assertEquals(2, [SELECT COUNT() FROM Contact WHERE AccountId = :accountId]);
    }

    @IsTest
    static void childCanRaiseItsOwnInsertMode() {
        // Parent NEVER (no DML), child NOW (real).
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId)
                                .setQuantity(2)
                                .setInsertMode(XFTY_InsertModeEnum.NOW)
                )
                .supplyBundle();

        System.assertEquals(null, bundle.primaryRecords()[0].Id, 'parent not inserted');
        System.assertEquals(2, [SELECT COUNT() FROM Contact], 'children inserted');
    }

    @IsTest
    static void mixingMockIdsWithRealDmlThrows() {
        try {
            new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .with(new XFTY_SObjectChildProvider(Contact.AccountId).setInsertMode(XFTY_InsertModeEnum.MOCK))
                    .supplyBundle();
            System.assert(false, 'expected a mixing exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('mix mock'), e.getMessage());
        }
    }

    @IsTest
    static void quantityBelowOneThrows() {
        try {
            new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(0);
            System.assert(false, 'expected a sanity exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('at least 1'), e.getMessage());
        }
    }

    // Bundle getters ---------------------------------------------------------------

    @IsTest
    static void getChildBundleMergesConfigsAndStaysNavigable() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .with(new XFTY_SObjectChildProvider(Case.AccountId, new Case(Origin = 'Web')).setQuantity(1))
                .with(new XFTY_SObjectChildProvider(Case.AccountId, new Case(Origin = 'Phone')).setQuantity(1))
                .supplyBundle();

        XFTY_DummySObjectBundle merged = bundle.getChildBundle(Case.AccountId);
        System.assertEquals(2, merged.primaryRecords().size());
        // both configs' Cases generated their own Contact parent
        System.assertEquals(2, merged.getBundle(Case.ContactId).primaryRecords().size());
    }

    // ------------------------------------------------------------------------------

    private class ChildTestLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<SObjectType, XFTY_DummySobjectProviderIntf> byType
                = new Map<SObjectType, XFTY_DummySobjectProviderIntf>{
                        Account.SObjectType => new XFTY_DefaultAccountDataProvider(),
                        Contact.SObjectType => new XFTY_DefaultContactDataProvider(),
                        Case.SObjectType => new CaseProvider()
                };

        public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
            return this.byType.get(sObjectType);
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
            return this.byType.get(lookupKey.getSObjectType());
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(sObj.getSObjectType()) };
        }
    }

    /** Case that needs a Contact (which in turn needs its own Account). */
    private class CaseProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                .put(Case.Subject, new XFTY_DummyDefaultValueIncrementingString('Case'))
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
