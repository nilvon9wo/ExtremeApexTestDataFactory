/**
 * Runnable proof for docs/use/relationships.md - required vs optional
 * relationships, the four inclusivity modes, cascading, PREVENT_CASCADE, and the
 * self-referential-cycle guard. Every `@IsTest` method is one example or table
 * row from that page.
 */
@IsTest
private class XFTY_Ex_RelationshipsTest {

    private static final XFTY_LookupKeyIntf TOP_ACCOUNT = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'top');

    // Contact --(required)--> Account --(required)--> Account (a distinct 'top' variant, so it is not a cycle)
    private static XFTY_DummySObjectProviderLookupIntf cascadeLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactRequiresAccount(),
                XFTY_LookupKey.get(Account.SObjectType) => new AccountRequiresTopParent(),
                TOP_ACCOUNT => new TopAccount()
        });
    }

    @IsTest
    static void testSupplyBundle_atRequiredInclusivity_generatesTheRequiredRelationshipNotTheOptionalOne() {
        // Arrange - a Contact with a required Account and an optional Owner
        XFTY_DummySObjectProviderLookupIntf lookup = requiredAndOptionalLookup();

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNotNull(bundle.getBundle(Contact.AccountId), 'the required Account is generated');
        Assert.isNull(bundle.getBundle(Contact.OwnerId), 'the optional Owner is not');
    }

    @IsTest
    static void testSupplyBundle_atAllInclusivity_generatesTheOptionalRelationshipToo() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = requiredAndOptionalLookup();

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNotNull(bundle.getBundle(Contact.AccountId), 'required, still generated');
        Assert.isNotNull(bundle.getBundle(Contact.OwnerId), 'optional, now generated under ALL');
    }

    @IsTest
    static void testSupplyBundle_atNoneInclusivity_generatesNoRelatedRecords() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = requiredAndOptionalLookup();

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(bundle.getBundle(Contact.AccountId), 'NONE generates no related records');
    }

    @IsTest
    static void testSupplyBundle_atRequiredInclusivity_cascadesThroughEveryLevel() {
        // Arrange - Contact -> Account -> top Account
        XFTY_DummySObjectProviderLookupIntf lookup = cascadeLookup();

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();
        Test.stopTest();

        // Assert - all three levels
        XFTY_DummySObjectBundle accountBundle = bundle.getBundle(Contact.AccountId);
        Assert.isNotNull(accountBundle, 'the Account');
        Assert.isNotNull(accountBundle.getBundle(Account.ParentId), 'and the Account own parent level');
    }

    @IsTest
    static void testSupplyBundle_atPreventCascadeInclusivity_generatesTheFirstLevelOnly() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = cascadeLookup();

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.PREVENT_CASCADE)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();
        Test.stopTest();

        // Assert
        XFTY_DummySObjectBundle accountBundle = bundle.getBundle(Contact.AccountId);
        Assert.isNotNull(accountBundle, 'the direct relationship is generated');
        Assert.isNull(accountBundle.getBundle(Account.ParentId), 'but it does not generate its own');
    }

    @IsTest
    static void testSupplyBundle_whenASelfReferentialChainGoesPastOneLevel_throwsACycleError() {
        // Arrange - one Account Provider that optionally parents another of itself
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountParentsItself()
                }
        );

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .includeOptional(new List<SObjectField>{ Account.ParentId, Account.ParentId })
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'the same Provider twice up one graph is a cycle');
        Assert.isTrue(thrown.getMessage().contains('cycle'), thrown.getMessage());
    }

    @IsTest
    static void testSupplyBundle_whenAllowAncestorCyclesIsSet_suppressesTheGuard() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountParentsItself()
                }
        );

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .includeOptional(new List<SObjectField>{ Account.ParentId, Account.ParentId })
                .allowAncestorCycles()
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();
        Test.stopTest();

        // Assert - the caller now owns the "does it terminate?" question; the two-hop path built two levels
        XFTY_DummySObjectBundle levelOne = bundle.getBundle(Account.ParentId);
        Assert.isNotNull(levelOne.getBundle(Account.ParentId), 'the forced two-hop path was allowed through');
    }

    // Fixture -------------------------------------------------------------

    private static XFTY_DummySObjectProviderLookupIntf requiredAndOptionalLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactRequiredAccountOptionalOwner(),
                XFTY_LookupKey.get(Account.SObjectType) => new PlainAccount(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
        });
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

    private class PlainAccount extends BaseProvider {
        private PlainAccount() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Acct'));
        }
    }

    private class ContactRequiredAccountOptionalOwner extends BaseProvider {
        private ContactRequiredAccountOptionalOwner() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('Rel'))
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
                    .putOptional(Contact.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
        }
    }

    private class ContactRequiresAccount extends BaseProvider {
        private ContactRequiresAccount() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('Casc'))
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));
        }
    }

    private class AccountRequiresTopParent extends BaseProvider {
        private AccountRequiresTopParent() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Mid'))
                    .putRequired(Account.ParentId, new XFTY_DummyDefaultRelationship(TOP_ACCOUNT, new Account()));
        }
    }

    private class TopAccount extends BaseProvider {
        private TopAccount() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Top'));
        }
    }

    private class AccountParentsItself extends BaseProvider {
        private AccountParentsItself() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Self'))
                    .putOptional(Account.ParentId, new XFTY_DummyDefaultRelationship(new Account()));
        }
    }
}
