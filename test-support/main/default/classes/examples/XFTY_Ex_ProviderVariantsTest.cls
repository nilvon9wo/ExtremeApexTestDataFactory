/**
 * Runnable proof for docs/use/provider-variants.md - selecting a Provider
 * variant as a consumer: withVariant(key), the lookup-key constructor, and
 * pinning a variant on a relationship.
 *
 * The "override template carrying a RecordTypeId" path needs real record-type
 * metadata (same known-gap bucket as XFTY_RecordTypeRealRtTest); it is proven
 * against an org, not here. These use plain flavour keys, which need no
 * metadata.
 */
@IsTest
private class XFTY_Ex_ProviderVariantsTest {

    private static final XFTY_LookupKeyIntf PARTNER = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'partner');

    private static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new StandardAccountProvider(),
                PARTNER => new PartnerAccountProvider(),
                XFTY_LookupKey.get(Case.SObjectType) => new CasePinningPartnerAccount()
        });
    }

    @IsTest
    static void testWithVariant_selectsTheNamedProvider() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .withVariant(PARTNER)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Account result = (Account) provider.supply();

        // Assert
        Assert.areEqual('Partner', result.Type, 'the partner variant generated the record');
    }

    @IsTest
    static void testConstructor_fromALookupKey_selectsTheNamedProvider() {
        // Arrange
        // nothing to arrange - the key carries the SObjectType and pins the variant

        // Act
        Account result = (Account) new XFTY_DummySObjectProvider(PARTNER, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();

        // Assert
        Assert.areEqual('Partner', result.Type);
    }

    @IsTest
    static void testSupplyBundle_whenARelationshipPinsAVariant_generatesThatParentVariant() {
        // Arrange - the Case Provider's required Account relationship pins PARTNER
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Case.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();

        // Assert
        Account generatedParent = (Account) bundle.getList(Case.AccountId)[0];
        Assert.areEqual('Partner', generatedParent.Type, 'the relationship chose the variant, not the default');
    }

    @IsTest
    static void testSupply_withoutAVariant_usesTheDefaultKeyProvider() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Account result = (Account) provider.supply();

        // Assert
        Assert.areEqual('Customer', result.Type, 'the plain-key Provider');
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

    private class StandardAccountProvider extends BaseProvider {
        private StandardAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Standard Acct'))
                    .put(Account.Type, 'Customer');
        }
    }

    private class PartnerAccountProvider extends BaseProvider {
        private PartnerAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Partner Acct'))
                    .put(Account.Type, 'Partner');
        }
    }

    private class CasePinningPartnerAccount extends BaseProvider {
        private CasePinningPartnerAccount() {
            this.template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                    .putRequired(Case.AccountId, new XFTY_DummyDefaultRelationship(PARTNER, new Account()));
        }
    }
}
