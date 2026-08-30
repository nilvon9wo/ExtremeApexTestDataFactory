/**
 * End-to-end coverage for multi-variant Provider resolution: one SObjectType,
 * several Providers, chosen by lookup key.
 */
@IsTest
private class XFTY_MultiVariantProviderTest {
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    private static final XFTY_LookupKeyIntf ENTERPRISE = new XFTY_FlavouredLookupKey(Account.SObjectType, 'enterprise');
    private static final XFTY_LookupKeyIntf SMB = new XFTY_FlavouredLookupKey(Account.SObjectType, 'smb');

    private static XFTY_SObjectProviderLookup newLookup() {
        return new XFTY_SObjectProviderLookup()
                .register(XFTY_LookupKey.get(Account.SObjectType), new SmbAccountProvider())
                .register(ENTERPRISE, new EnterpriseAccountProvider())
                .register(SMB, new SmbAccountProvider())
                .register(XFTY_LookupKey.get(Contact.SObjectType), new EnterpriseParentedContactProvider());
    }

    @IsTest
    static void getByExplicitKeyReturnsTheMatchingProvider() {
        XFTY_SObjectProviderLookup lookup = newLookup();

        Assert.isInstanceOfType(lookup.get(ENTERPRISE), EnterpriseAccountProvider.class);
        Assert.isInstanceOfType(lookup.get(SMB), SmbAccountProvider.class);
        Assert.isInstanceOfType(lookup.get(Account.SObjectType), SmbAccountProvider.class);
    }

    @IsTest
    static void aRelationshipPinsItsProviderVariantByExplicitKey() {
        // EnterpriseParentedContactProvider's required Account relationship pins the 'enterprise' variant.
        Account generatedParent;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, newLookup())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            generatedParent = (Account) bundle.getList(Contact.AccountId)[0];
        }
        Test.stopTest();

        Assert.areEqual('Enterprise', generatedParent.Industry, 'The enterprise variant should have generated the Account');
    }

    @IsTest
    static void providerLevelPutCanPinADifferentVariant() {
        Account generatedParent;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, newLookup())
                    .putRequired(
                            Contact.AccountId,
                            new XFTY_DummyDefaultRelationship(SMB, new Account())
                    )
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            generatedParent = (Account) bundle.getList(Contact.AccountId)[0];
        }
        Test.stopTest();

        Assert.areEqual('SMB', generatedParent.Industry);
    }

    @IsTest
    static void withoutAnExplicitKeyTheDefaultVariantIsUsed() {
        Account generatedParent;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, newLookup())
                    .putRequired(
                            Contact.AccountId,
                            new XFTY_DummyDefaultRelationship(new Account())
                    )
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            generatedParent = (Account) bundle.getList(Contact.AccountId)[0];
        }
        Test.stopTest();

        Assert.areEqual('SMB', generatedParent.Industry, 'The default (plain-key) Account Provider should have been used');
    }

    // --- in-test Providers -------------------------------------------------------

    private abstract class BaseProvider implements XFTY_DummySobjectProviderIntf {
        protected XFTY_DummySObjectMasterTemplate template;

        public SObjectField getPrimaryTargetField() {
            return this.template.primaryTargetField;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(
                XFTY_DummySObjectProviderLookupIntf providerLookup,
                List<SObject> templateSObjectList,
                XFTY_InsertModeEnum insertMode,
                XFTY_InsertInclusivityEnum inclusivity
        ) {
            return XFTY_DummySObjectFactory.createBundle(
                    providerLookup, this.template, templateSObjectList, insertMode, inclusivity
            );
        }
    }

    private class EnterpriseAccountProvider extends BaseProvider {
        private EnterpriseAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_DummyDefaultValueIncrementingString('Enterprise Account'))
                    .put(Account.Industry, 'Enterprise');
        }
    }

    private class SmbAccountProvider extends BaseProvider {
        private SmbAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_DummyDefaultValueIncrementingString('SMB Account'))
                    .put(Account.Industry, 'SMB');
        }
    }

    private class EnterpriseParentedContactProvider extends BaseProvider {
        private EnterpriseParentedContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_DummyDefaultValueIncrementingString('Variant Contact'))
                    .putRequired(
                            Contact.AccountId,
                            new XFTY_DummyDefaultRelationship(
                                    new XFTY_FlavouredLookupKey(Account.SObjectType, 'enterprise'),
                                    new Account()
                            )
                    );
        }
    }
}
