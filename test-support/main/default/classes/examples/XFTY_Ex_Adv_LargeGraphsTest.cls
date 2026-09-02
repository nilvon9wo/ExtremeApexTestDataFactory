/**
 * Runnable proof for docs/use/advanced/large-graphs.md - the levers that keep a
 * big graph inside the governor limits. The "XFTY warns when you're close"
 * behaviour is proven by the XFTY_Load suite and XFTY_GovernorBudget's tests.
 */
@IsTest
private class XFTY_Ex_Adv_LargeGraphsTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // Case --(required)--> Account and --(required)--> Contact (no parent of its own).
    // Both parents sit at the same dependency depth.
    private static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Case.SObjectType) => new CaseWithTwoParents(),
                XFTY_LookupKey.get(Account.SObjectType) => new PlainAccount(),
                XFTY_LookupKey.get(Contact.SObjectType) => new ParentlessContact(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
        });
    }

    @IsTest
    static void testSupplyBundle_atRequiredInclusivity_leavesTheOptionalOwnerOut() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Case.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(bundle.getBundle(Case.OwnerId), 'REQUIRED leaves the optional Owner out');
    }

    @IsTest
    static void testSupplyBundle_atAllInclusivity_pullsInTheOptionalOwner() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Case.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNotNull(bundle.getBundle(Case.OwnerId), 'ALL pulls it in - a bigger graph');
    }

    @IsTest
    static void testSupplyBundle_whenDepthBatched_collapsesTwoProvidersAtOneDepthIntoOneInsert() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Case.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .depthBatched();

        // Act
        Integer statementsUsed;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            provider.supplyBundle();
            statementsUsed = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert - depth 1 = { Account, Contact } in one insert, depth 2 = { Case } => 2
        Assert.areEqual(2, statementsUsed, 'one insert per dependency depth');
    }

    @IsTest
    static void testSupplyBundle_withoutDepthBatching_eachProviderInsertsSeparately() {
        // Arrange - the same graph, depthBatched() left off
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Case.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW);

        // Act
        Integer statementsUsed;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            provider.supplyBundle();
            statementsUsed = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert - Account, Contact, Case each inserted on their own => 3
        Assert.areEqual(3, statementsUsed, 'one insert per Provider is the trade-off depthBatched() addresses');
    }

    // Fixture -----------------------------------------------

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

    private class CaseWithTwoParents extends BaseProvider {
        private CaseWithTwoParents() {
            this.template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                    .putRequired(Case.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
                    .putRequired(Case.ContactId, new XFTY_DummyDefaultRelationship(new Contact()))
                    .putOptional(Case.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
        }
    }

    private class PlainAccount extends BaseProvider {
        private PlainAccount() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('LG Acct'));
        }
    }

    private class ParentlessContact extends BaseProvider {
        private ParentlessContact() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('LG Contact'));
        }
    }
}
