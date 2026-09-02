/**
 * Runnable proof for docs/use/per-call-relationships.md - includeOptional(field),
 * includeOptional(path), and excludeRelationship(field), each acting on the one
 * Provider instance for one call. (put(path, value) is proven separately by
 * XFTY_PathValueTest - see docs/use/value-expressions.md.)
 */
@IsTest
private class XFTY_Ex_PerCallRelationshipsTest {

    private static final XFTY_LookupKeyIntf TOP_ACCOUNT = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'top');

    private static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactProvider(),
                XFTY_LookupKey.get(Account.SObjectType) => new AccountProvider(),
                TOP_ACCOUNT => new TopAccountProvider(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
        });
    }

    @IsTest
    static void testIncludeOptional_generatesOneNamedRelationshipWhateverTheInclusivity() {
        // Arrange - default (NONE) inclusivity, but ask for the optional Owner
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .includeOptional(Contact.OwnerId)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();

        // Assert
        Assert.isNotNull(bundle.getBundle(Contact.OwnerId), 'the named optional relationship is generated');
        Assert.isNull(bundle.getBundle(Contact.AccountId), 'everything not named stays at the call inclusivity (NONE)');
    }

    @IsTest
    static void testExcludeRelationship_makesOneRelationshipNonExistentForThisCall() {
        // Arrange - REQUIRED inclusivity would normally generate the Account
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .excludeRelationship(Contact.AccountId)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();

        // Assert
        Assert.isNull(bundle.getBundle(Contact.AccountId), 'not generated, not attached, not an orphan reference');
        Assert.areEqual(null, bundle.getList(Contact.Id)[0].get(Contact.AccountId), 'the FK is left unset');
    }

    @IsTest
    static void testIncludeOptional_withAPath_forcesEveryStep() {
        // Arrange - REQUIRED overall, but force the Account's own optional parent for this call
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .includeOptional(new List<SObjectField>{ Contact.AccountId, Account.ParentId })
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();

        // Assert
        XFTY_DummySObjectBundle accountBundle = bundle.getBundle(Contact.AccountId);
        Assert.isNotNull(accountBundle, 'the Account (required)');
        Assert.isNotNull(accountBundle.getBundle(Account.ParentId), 'and its optional parent, forced by the path');
    }

    @IsTest
    static void testSupplyBundle_whenAPathStepIsUnknown_throwsDuringGeneration() {
        // Arrange - LastName is a plain field, not a relationship
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .includeOptional(Contact.LastName)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Exception thrown;
        try {
            provider.supplyBundle();
        } catch (Exception ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'includeOptional on a non-relationship is a loud error, never a silent no-op');
    }

    // Fixture -------------------------------------------------------------

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

    private class ContactProvider extends BaseProvider {
        private ContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('PerCall'))
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
                    .putOptional(Contact.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
        }
    }

    private class AccountProvider extends BaseProvider {
        private AccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('PerCall Acct'))
                    .putOptional(Account.ParentId, new XFTY_DummyDefaultRelationship(TOP_ACCOUNT, new Account()));
        }
    }

    private class TopAccountProvider extends BaseProvider {
        private TopAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('PerCall Top'));
        }
    }
}
