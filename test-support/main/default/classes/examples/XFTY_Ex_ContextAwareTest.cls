/**
 * Runnable proof for docs/use/context-aware-values.md - a value that sees the
 * rest of the record: a sibling copy, an ancestor copy (one hop and multi-hop),
 * a custom XFTY_ContextAwareExpressionIntf, the put-order rule, and an up-flowing
 * read from a child. Every `@IsTest` method is one example from that page.
 */
@IsTest
private class XFTY_Ex_ContextAwareTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testSupply_withCopyFromSibling_fillsAFieldFromAnotherOnTheSameRecord() {
        // Arrange
        // nothing to arrange - ShippingCity is put first, BillingCity copies it

        // Act
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.ShippingCity, 'Berlin')
                .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Berlin', result.BillingCity);
    }

    @IsTest
    static void testSupply_withCopyFromAncestor_readsAFieldOffAGeneratedParent() {
        // Arrange - the Contact's generated Account has a Site
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactReadingAccountSite(),
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountWithSite()
                }
        );

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('HQ-SITE', result.Department, 'copied from the generated Account Site');
    }

    @IsTest
    static void testSupply_withCopyFromAncestor_walksAMultiHopPath() {
        // Arrange - Contact -> Account -> top Account; read the top Account's Name
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactReadingGrandparentName(),
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountWithTopParent(),
                        TOP_ACCOUNT => new NamedTopAccount()
                }
        );

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('THE-TOP', result.Description, 'read two relationships up');
    }

    @IsTest
    static void testSupply_withACustomContextAwareValue_readsASiblingThroughTheContext() {
        // Arrange
        // nothing to arrange - Birthdate is put first, the flag derives from it

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.Birthdate, Date.newInstance(2000, 1, 1))
                .put(Contact.Description, new IsAdultFlag())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('true', result.Description);
    }

    @IsTest
    static void testSupply_whenReadingALaterContextAwareValue_throwsNamingBothFields() {
        // Arrange - BillingCity reads ShippingCity, but ShippingCity is put AFTER it
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
                .put(Account.ShippingCity, new XFTY_CopyFromSiblingExpression(Account.Site))
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Exception thrown;
        try {
            provider.supply();
        } catch (Exception ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'a mis-ordered sibling read is a loud error, never a silent null');
    }

    @IsTest
    static void testFlush_withCopyFromDescendant_pullsAChildFieldUpUnderDeferred() {
        // Arrange - an Account whose Site copies its primary Contact's Department
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactUnderAccount(),
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

    private static final XFTY_LookupKeyIntf TOP_ACCOUNT = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'top');

    private class IsAdultFlag implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            Date birthdate = (Date) context.siblingValue(Contact.Birthdate);
            return String.valueOf(birthdate != null && birthdate.addYears(18) <= Date.today());
        }
    }

    private abstract class BaseProvider implements XFTY_DummySobjectProviderIntf {
        protected XFTY_DummySObjectMasterTemplate template;
        public SObjectField getPrimaryTargetField() {
            return this.template.primaryTargetField;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }

    private class AccountWithSite extends BaseProvider {
        private AccountWithSite() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Acct'))
                    .put(Account.Site, 'HQ-SITE');
        }
    }

    private class ContactReadingAccountSite extends BaseProvider {
        private ContactReadingAccountSite() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('CA'))
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
                    .put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Site));
        }
    }

    private class NamedTopAccount extends BaseProvider {
        private NamedTopAccount() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, 'THE-TOP');
        }
    }

    private class AccountWithTopParent extends BaseProvider {
        private AccountWithTopParent() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Mid'))
                    .putRequired(Account.ParentId, new XFTY_DummyDefaultRelationship(TOP_ACCOUNT, new Account()));
        }
    }

    private class ContactReadingGrandparentName extends BaseProvider {
        private ContactReadingGrandparentName() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('CG'))
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
                    .put(Contact.Description, new XFTY_CopyFromAncestorExpression(new List<SObjectField>{
                            Contact.AccountId, Account.ParentId, Account.Name
                    }));
        }
    }

    private class ContactUnderAccount extends BaseProvider {
        private ContactUnderAccount() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('CU'))
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));
        }
    }

    private class AccountReadingChildDepartment extends BaseProvider {
        private AccountReadingChildDepartment() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('ACD'))
                    .put(Account.Site, new XFTY_CopyFromDescendantExpression(Contact.AccountId, Contact.Department));
        }
    }
}
