/**
 * Proves the fluent public API of `XFTY_DummySObjectProvider` - one test per
 * affordance: the constructors and their guards, the setters, `withVariant`,
 * `put(...)` routing, `includeOptional` / `excludeRelationship`, precedence.
 * MOCK / NEVER mode throughout - no DML/SOQL, so no `System.runAs`. End-to-end
 * scenarios live in `XFTY_DummySObjectProviderScenarioTest`.
 */
@IsTest
private class XFTY_DummySObjectProviderApiTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    private static XFTY_DummySObjectProvider contactProvider() {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP).setInsertMode(XFTY_InsertModeEnum.MOCK);
    }

    // Constructor guards ------------------------------------------

    @IsTest
    static void testConstructor_whenTheSObjectTypeIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            new XFTY_DummySObjectProvider((SObjectType) null, LOOKUP);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('SObjectType to request data'), thrown.getMessage());
    }

    @IsTest
    static void testConstructor_whenTheProviderLookupIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, null);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Dummy SObject Provider Lookup'), thrown.getMessage());
    }

    @IsTest
    static void testConstructor_whenTheLookupKeyIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            new XFTY_DummySObjectProvider((XFTY_LookupKeyIntf) null, LOOKUP);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('lookup key'), thrown.getMessage());
    }

    @IsTest
    static void testConstructor_whenTheTemplateListIsEmpty_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            new XFTY_DummySObjectProvider(new List<SObject>(), LOOKUP);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('empty or null template list'), thrown.getMessage());
    }

    @IsTest
    static void testConstructor_whenTheTemplateListsFirstEntryIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            new XFTY_DummySObjectProvider(new List<SObject>{ null }, LOOKUP);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('empty or null template list'), thrown.getMessage());
    }

    // Convenience constructors ----------------------------------

    @IsTest
    static void testConstructor_fromALookupKey_pinsTheVariantAndDerivesTheType() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(XFTY_LookupKey.get(Contact.SObjectType), LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.Id);
        Assert.isTrue(result.LastName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void testConstructor_fromATemplate_derivesTheTypeAndAppliesTheOverride() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(new Contact(FirstName = 'Zoe'), LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Zoe', result.FirstName);
        Assert.isTrue(result.LastName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void testConstructor_fromATemplateList_derivesTheTypeAndKeepsEachTemplate() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(
                new List<Contact>{ new Contact(FirstName = 'Alice'), new Contact(FirstName = 'Bob') }, LOOKUP
        ).setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        List<SObject> results = provider.supplyList();
        Test.stopTest();

        // Assert
        Assert.areEqual(2, results.size());
        Assert.areEqual('Alice', (String) results[0].get(Contact.FirstName));
        Assert.areEqual('Bob', (String) results[1].get(Contact.FirstName));
    }

    // Setter guards -------------------------------------------

    @IsTest
    static void testSetQuantityPerTemplate_whenGivenAValueBelowOne_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider();

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            provider.setQuantityPerTemplate(0);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('makes no sense'), thrown.getMessage());
    }

    @IsTest
    static void testSetOverrideTemplateList_whenGivenMixedSObjectTypes_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider();

        // Act
        XFTY_DummySObjectProvider.ConflictException thrown;
        Test.startTest();
        try {
            provider.setOverrideTemplateList(new List<SObject>{ new Contact(), new Account() });
        } catch (XFTY_DummySObjectProvider.ConflictException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Account override template'), thrown.getMessage());
    }

    @IsTest
    static void testSetOverrideTemplateList_whenGivenAHomogeneousListOfTheWrongType_throws() {
        // Arrange - a homogeneous list of the "wrong" type used to silently retarget the Provider
        XFTY_DummySObjectProvider provider = contactProvider();

        // Act
        XFTY_DummySObjectProvider.ConflictException thrown;
        Test.startTest();
        try {
            provider.setOverrideTemplateList(new List<SObject>{ new Account() });
        } catch (XFTY_DummySObjectProvider.ConflictException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'the constructor asked for Contact');
        Assert.isTrue(thrown.getMessage().contains('requests Contact'), thrown.getMessage());
    }

    @IsTest
    static void testSetOverrideTemplateList_whenGivenNullThenEmpty_toleratesBothAndGeneratesABlankRecord() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(null)
                .setOverrideTemplateList(new List<SObject>())
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.Id, 'a blank template is generated when no overrides are supplied');
    }

    @IsTest
    static void testConstructor_fromAHomogeneousTemplateList_isAccepted() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(
                new List<SObject>{ new Contact(FirstName = 'A'), new Contact(FirstName = 'B') }, LOOKUP
        ).setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        List<SObject> results = provider.supplyList();
        Test.stopTest();

        // Assert
        Assert.areEqual(2, results.size());
    }

    // withVariant --------------------------------------------

    @IsTest
    static void testWithVariant_forAMatchingKey_pinsItAndGenerates() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .withVariant(XFTY_LookupKey.get(Contact.SObjectType))
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.Id);
        Assert.isTrue(result.LastName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void testWithVariant_whenTheKeyIsNull_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP);

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            provider.withVariant(null);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('variant key is required'), thrown.getMessage());
    }

    @IsTest
    static void testWithVariant_whenTheKeyIsForAnotherSObjectType_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP);

        // Act
        XFTY_DummySObjectProvider.ConflictException thrown;
        Test.startTest();
        try {
            provider.withVariant(XFTY_LookupKey.get(Account.SObjectType));
        } catch (XFTY_DummySObjectProvider.ConflictException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Account'), thrown.getMessage());
        Assert.isTrue(thrown.getMessage().contains('Contact'), thrown.getMessage());
    }

    @IsTest
    static void testWithVariant_whenCalledAfterPut_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, 'x');

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            provider.withVariant(XFTY_LookupKey.get(Contact.SObjectType));
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('withVariant'), thrown.getMessage());
    }

    // put(...) routing -----------------------------------

    @IsTest
    static void testPut_forAValueExpressionPassedAsObject_routesItCorrectly() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider()
                .put(Contact.FirstName, (Object) new XFTY_LiteralExpression('RoutedStrategy'));

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('RoutedStrategy', result.FirstName);
    }

    @IsTest
    static void testPut_forAContextAwareExpressionPassedAsObject_routesItCorrectly() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider()
                .put(Contact.FirstName, 'Source')
                .put(Contact.Department, (Object) new XFTY_CopyFromSiblingExpression(Contact.FirstName));

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Source', result.Department, 'a context-aware expression passed as Object still routes correctly');
    }

    @IsTest
    static void testPut_whenGivenARelationship_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            provider.put(Contact.AccountId, (Object) new XFTY_DummyDefaultRelationship(new Account()));
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('putRequired'), thrown.getMessage());
    }

    @IsTest
    static void testPut_forAValueExpression_replacesTheGenerationStrategyForAField() {
        // Regression guard: a defect previously made provider-level put(...) a no-op.
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider()
                .put(Contact.FirstName, new XFTY_LiteralExpression('DeliberateName'));

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('DeliberateName', result.FirstName);
    }

    @IsTest
    static void testPut_forABareLiteral_treatsItAsAnExactValue() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider().put(Contact.FirstName, 'LiteralFirstName');

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('LiteralFirstName', result.FirstName);
    }

    @IsTest
    static void testSetOverrideTemplate_winsOverPut() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider()
                .put(Contact.FirstName, new XFTY_LiteralExpression('FromPut'))
                .setOverrideTemplate(new Contact(FirstName = 'FromOverride'));

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('FromOverride', result.FirstName);
    }

    @IsTest
    static void testPut_onOneProvider_doesNotLeakIntoALaterSeparateProvider() {
        // Arrange - customise one Provider, then build a pristine one on the same lookup
        contactProvider().put(Contact.FirstName, new XFTY_LiteralExpression('Customized')).supply();

        // Act
        Test.startTest();
        Contact pristine = (Contact) contactProvider().supply();
        Test.stopTest();

        // Assert
        Assert.isTrue(
                pristine.FirstName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_FIRST_NAME_PREFIX),
                'expected the default prefix, got: ' + pristine.FirstName
        );
    }

    // removeFromMasterTemplate -----------------------------

    @IsTest
    static void testRemoveFromMasterTemplate_dropsAGeneratedValueAndLeavesOtherDefaults() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .removeFromMasterTemplate(Contact.Email)
                .setInsertMode(XFTY_InsertModeEnum.NEVER);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isNull(result.Email, 'Email is no longer generated once removed');
        Assert.isNotNull(result.LastName, 'other defaults are unaffected');
    }

    // putOptional / includeOptional / excludeRelationship ---

    @IsTest
    static void testPutOptional_atRequiredInclusivity_theOptionalRelationshipIsSkipped() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()))
                .removeFromMasterTemplate(Contact.AccountId)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(bundle.getList(Contact.ReportsToId), 'an optional relationship is skipped for REQUIRED');
    }

    @IsTest
    static void testPutOptional_atAllInclusivity_theOptionalRelationshipIsGenerated() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()))
                .removeFromMasterTemplate(Contact.AccountId)
                .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.ReportsToId).size(), 'an optional relationship is generated for ALL');
    }

    @IsTest
    static void testIncludeOptional_atRequiredInclusivity_promotesJustThatOptionalRelationship() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()))
                .includeOptional(Contact.ReportsToId)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.ReportsToId).size(), 'the included optional relationship is generated');
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the required Account is still generated');
    }

    @IsTest
    static void testIncludeOptional_onAnAlreadyRequiredRelationship_isANoOp() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .includeOptional(Contact.AccountId)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the required Account is generated, exactly once');
    }

    @IsTest
    static void testIncludeOptional_whenTheFieldIsNotARelationship_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .includeOptional(Contact.FirstName)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
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
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('is not a relationship'), thrown.getMessage());
    }

    @IsTest
    static void testExcludeRelationship_skipsARequiredRelationshipAndLeavesNoOrphanReference() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .excludeRelationship(Contact.AccountId)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(bundle.getList(Contact.AccountId), 'the excluded relationship is not generated');
        Assert.isNull(((Contact) bundle.getList(Contact.Id)[0]).AccountId, 'and not left as an orphan reference');
    }

    @IsTest
    static void testExcludeRelationship_isInstanceLocal() {
        // Arrange - a separate Provider on the same lookup, no exclusion
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .excludeRelationship(Contact.AccountId)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);
        XFTY_DummySObjectBundle normal = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle excluded = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(excluded.getList(Contact.AccountId));
        Assert.areEqual(1, normal.getList(Contact.AccountId).size(),
                'a separate Provider on the same lookup still generates the relationship');
    }

    @IsTest
    static void testExcludeRelationship_whenGivenAPlainValueField_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP);

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            provider.excludeRelationship(Contact.FirstName);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('no relationship'), thrown.getMessage());
    }

    // supply / supplyList ----------------------------------

    @IsTest
    static void testSupply_returnsASingleRecordWithMasterTemplateDefaults() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider();

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.Id);
        Assert.isTrue(result.FirstName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_FIRST_NAME_PREFIX));
        Assert.isTrue(result.LastName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void testSupplyList_appliesQuantityOutsideTheTemplateLoop() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider()
                .setOverrideTemplateList(new List<SObject>{
                        new Contact(FirstName = 'Alice'), new Contact(FirstName = 'Bob')
                })
                .setQuantityPerTemplate(2);

        // Act
        Test.startTest();
        List<SObject> results = provider.supplyList();
        Test.stopTest();

        // Assert
        Assert.areEqual(4, results.size(), 'two templates x quantity 2');
        List<String> firstNames = new List<String>();
        for (SObject record : results) {
            firstNames.add((String) record.get(Contact.FirstName));
        }
        Assert.areEqual(new List<String>{ 'Alice', 'Bob', 'Alice', 'Bob' }, firstNames, 'A, B, A, B - not A, A, B, B');
    }
}
