/**
 * Proves ancestor-cycle detection in `XFTY_AncestorGenerator`: a self-referential
 * relationship generates one level, a deeper same-key chain throws, and
 * `.allowAncestorCycles()` suppresses the guard. MOCK mode - no DML/SOQL.
 */
@IsTest
private class XFTY_AncestorCycleTest {

    private static XFTY_DummySObjectProviderLookupIntf selfReferringLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Contact.SObjectType) => new SelfReferringContactProvider()
        });
    }

    @IsTest
    static void testSupplyBundle_withOneLevelOfSelfReference_stopsTheChainOnItsOwn() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, selfReferringLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .includeOptional(Contact.ReportsToId)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Sanity Check
        Assert.isNotNull(bundle.getBundle(Contact.ReportsToId), 'the manager Contact was generated');

        // Assert
        Assert.isNull(
                bundle.getBundle(Contact.ReportsToId).getBundle(Contact.ReportsToId),
                'the manager Contact does not get its own manager - the chain stops'
        );
    }

    @IsTest
    static void testSupplyBundle_whenAForcedPathRepeatsTheSameRelationshipKey_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, selfReferringLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .includeOptional(new List<SObjectField>{ Contact.ReportsToId, Contact.ReportsToId })
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            provider.supplyBundle();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a deeper same-key chain must throw');
        Assert.isTrue(thrown.getMessage().contains('cycle'), thrown.getMessage());
        Assert.isTrue(thrown.getMessage().contains('ReportsToId'), thrown.getMessage());
    }

    @IsTest
    static void testSupplyBundle_whenAllowAncestorCyclesIsSet_buildsTheForcedDeepChainThenStops() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, selfReferringLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .includeOptional(new List<SObjectField>{ Contact.ReportsToId, Contact.ReportsToId })
                .allowAncestorCycles()
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        XFTY_DummySObjectBundle levelTwo = bundle.getBundle(Contact.ReportsToId).getBundle(Contact.ReportsToId);
        Assert.isNotNull(levelTwo, 'the two-hop forced path built a two-deep chain');
        Assert.isNull(levelTwo.getBundle(Contact.ReportsToId), 'and then it stops');
    }

    private class SelfReferringContactProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_IncrementingStringExpression('Mgr'))
                .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()));

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
