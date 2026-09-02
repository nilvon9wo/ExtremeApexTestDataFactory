/**
 * Proves multi-variant Provider resolution end to end: one SObjectType, several
 * Providers, chosen by lookup key. MOCK mode throughout - no DML/SOQL, so no
 * `System.runAs`.
 */
@IsTest
private class XFTY_MultiVariantProviderTest {

    // Shared keys - in a real project these live in a `*LookupKeys` constants class
    // that both the Provider Lookup and the pinning relationships reference.
    private static final XFTY_LookupKeyIntf ENTERPRISE = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'enterprise');
    private static final XFTY_LookupKeyIntf SMB = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'smb');

    private static XFTY_DummySObjectProviderLookupIntf newLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new NamedAccountProvider('SMB'),
                ENTERPRISE => new NamedAccountProvider('Enterprise'),
                SMB => new NamedAccountProvider('SMB'),
                XFTY_LookupKey.get(Contact.SObjectType) => new EnterpriseParentedContactProvider()
        });
    }

    // lookup.get(key) ------------------------------------------------

    @IsTest
    static void testGet_forAnExplicitEnterpriseKey_returnsTheEnterpriseProvider() {
        testGetIndustry(ENTERPRISE, 'Enterprise');
    }

    @IsTest
    static void testGet_forAnExplicitSmbKey_returnsTheSmbProvider() {
        testGetIndustry(SMB, 'SMB');
    }

    @IsTest
    static void testGet_forThePlainTypeKey_returnsTheDefaultProvider() {
        testGetIndustry(XFTY_LookupKey.get(Account.SObjectType), 'SMB');
    }

    // Variant chosen while generating a related record ---------------

    @IsTest
    static void testSupplyBundle_whenTheProvidersRelationshipPinsAVariantByKey_generatesThatVariant() {
        // Arrange - EnterpriseParentedContactProvider's required Account relationship pins 'enterprise'
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, newLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual('Enterprise', ((Account) bundle.getList(Contact.AccountId)[0]).Industry);
    }

    @IsTest
    static void testSupplyBundle_whenAPerCallRelationshipPinsADifferentVariant_generatesThatVariant() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, newLookup())
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(SMB, new Account()))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual('SMB', ((Account) bundle.getList(Contact.AccountId)[0]).Industry);
    }

    @IsTest
    static void testSupplyBundle_whenAPerCallRelationshipCarriesNoKey_generatesTheDefaultVariant() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, newLookup())
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual('SMB', ((Account) bundle.getList(Contact.AccountId)[0]).Industry, 'the plain-key Provider');
    }

    // Runner -------------------------------------------------------

    static void testGetIndustry(XFTY_LookupKeyIntf key, String expectedIndustry) {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(key, newLookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Account result = (Account) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedIndustry, result.Industry);
    }

    // In-test Providers ------------------------------------------------

    private abstract class BaseProvider implements XFTY_DummySobjectProviderIntf {
        protected XFTY_DummySObjectMasterTemplate template;

        public SObjectField getPrimaryTargetField() {
            return this.template.primaryTargetField;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    private class NamedAccountProvider extends BaseProvider {
        private NamedAccountProvider(String industry) {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression(industry + ' Account'))
                    .put(Account.Industry, industry);
        }
    }

    private class EnterpriseParentedContactProvider extends BaseProvider {
        private EnterpriseParentedContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('Variant Contact'))
                    .putRequired(
                            Contact.AccountId,
                            // The relationship pins the same shared key the lookup registers.
                            new XFTY_DummyDefaultRelationship(ENTERPRISE, new Account())
                    );
        }
    }
}
