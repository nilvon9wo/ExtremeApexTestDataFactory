/**
 * Runnable proof for docs/use/advanced/matching-values.md - defining a
 * field-pair relationship once. Every `@IsTest` method is one example from that
 * page.
 */
@IsTest
private class XFTY_Ex_Adv_MatchingValuesTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testSupply_withASiblingCopy_keepsTwoFieldsOnOneRecordInSync() {
        // Arrange
        // nothing to arrange - ShippingCountry is set, BillingCountry follows

        // Act
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.ShippingCountry, 'Germany')
                .put(Account.BillingCountry, new XFTY_CopyFromSiblingExpression(Account.ShippingCountry))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Germany', result.ShippingCountry);
        Assert.areEqual('Germany', result.BillingCountry, 'defined once, copied to the pair');
    }

    @IsTest
    static void testSupply_withACustomExpression_derivesTheSecondFieldWhenItIsNotAStraightCopy() {
        // Arrange
        // nothing to arrange

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.MailingCountry, 'Germany')
                .put(Contact.Description, new SiblingCountryLabel())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Billing: Germany', result.Description);
    }

    @IsTest
    static void testSupplyList_withASharedAncestorAndCopyingRelatedField_putsAParentValueOnEveryChild() {
        // Arrange - many Cases under one shared Account; each Case carries the Account's OwnerId
        XFTY_SharedAncestor.put('hq', new Account(Name = 'HQ', OwnerId = TEST_ADMIN.Id))
                .copyingRelatedField(Account.OwnerId);

        // Act
        List<Case> results;
        Test.startTest();
        results = (List<Case>) new XFTY_DummySObjectProvider(Case.SObjectType, casesUnderHq())
                .setQuantityPerTemplate(4)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert
        Assert.areEqual(4, results.size());
        for (Case supportCase : results) {
            Assert.areEqual(TEST_ADMIN.Id, supportCase.AccountId, 'the child field holds the Account OwnerId, not the Account Id');
        }
    }

    @IsTest
    static void testFlush_withCopyFromDescendant_pullsAChildValueUpOntoTheParent() {
        // Arrange - a Contact pulls in an Account whose Site copies the Contact's Department
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactUnderReadingAccount(),
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountReadingChildDepartment()
                }
        );

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .put(Contact.Department, 'Field Ops')
                    .supply();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual('Field Ops', [SELECT Site FROM Account].Site, 'the parent copied the value up at flush');
    }

    // Fixture -------------------------------------------------------------

    private static XFTY_DummySObjectProviderLookupIntf casesUnderHq() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Case.SObjectType) => new CaseUnderSharedHq()
        });
    }

    private class SiblingCountryLabel implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            return 'Billing: ' + (String) context.siblingValue(Contact.MailingCountry);
        }
    }

    private class CaseUnderSharedHq implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                .putRequired(Case.AccountId, XFTY_SharedAncestor.get('hq'));
        public SObjectField getPrimaryTargetField() {
            return Case.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }

    private class AccountReadingChildDepartment implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_IncrementingStringExpression('Acct'))
                .put(Account.Site, new XFTY_CopyFromDescendantExpression(Contact.AccountId, Contact.Department));
        public SObjectField getPrimaryTargetField() {
            return Account.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }

    private class ContactUnderReadingAccount implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_IncrementingStringExpression('Leaf'))
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));
        public SObjectField getPrimaryTargetField() {
            return Contact.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }
}
