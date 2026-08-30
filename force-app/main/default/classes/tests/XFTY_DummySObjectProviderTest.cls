/**
 * Coverage for the fluent public entry point, `XFTY_DummySObjectProvider`:
 * constructor guards, the setters, and the customization surface documented in
 * docs/customization.md.
 *
 * The end-to-end generation behaviour (insert modes, relationship inclusivity)
 * is exercised in `XFTY_DummySObjectFactoryTest`.
 */
@IsTest
private class XFTY_DummySObjectProviderTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    // Constructor guards --------------------------------------------------------

    @IsTest
    static void constructorRejectsNullSObjectType() {
        try {
            new XFTY_DummySObjectProvider((SObjectType) null, LOOKUP);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('SObjectType to request data'), ex.getMessage());
        }
    }

    // Convenience constructors ------------------------------------------------

    @IsTest
    static void constructorFromLookupKeyPinsTheVariantAndType() {
        Contact result = (Contact) new XFTY_DummySObjectProvider(XFTY_LookupKey.get(Contact.SObjectType), LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();

        Assert.isNotNull(result.Id);
        Assert.isTrue(result.LastName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void constructorFromNullLookupKeyThrows() {
        try {
            new XFTY_DummySObjectProvider((XFTY_LookupKeyIntf) null, LOOKUP);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('lookup key'), ex.getMessage());
        }
    }

    @IsTest
    static void constructorFromTemplateDerivesTypeAndAppliesTheOverride() {
        Contact result = (Contact) new XFTY_DummySObjectProvider(new Contact(FirstName = 'Zoe'), LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();

        Assert.areEqual('Zoe', result.FirstName);
        Assert.isTrue(result.LastName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void constructorFromTemplateListDerivesTypeAndKeepsEachTemplate() {
        List<SObject> results = new XFTY_DummySObjectProvider(
                new List<Contact>{ new Contact(FirstName = 'Alice'), new Contact(FirstName = 'Bob') },
                LOOKUP
        )
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();

        Assert.areEqual(2, results.size());
        Assert.areEqual('Alice', (String) results[0].get(Contact.FirstName));
        Assert.areEqual('Bob', (String) results[1].get(Contact.FirstName));
    }

    @IsTest
    static void constructorFromEmptyTemplateListThrows() {
        try {
            new XFTY_DummySObjectProvider(new List<SObject>(), LOOKUP);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('empty or null template list'), ex.getMessage());
        }
    }

    @IsTest
    static void constructorFromATemplateListWhoseFirstEntryIsNullThrows() {
        try {
            new XFTY_DummySObjectProvider(new List<SObject>{ null }, LOOKUP);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('empty or null template list'), ex.getMessage());
        }
    }

    @IsTest
    static void constructorRejectsNullProviderLookup() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, null);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('Dummy SObject Provider Lookup'), ex.getMessage());
        }
    }

    // Setter guards -----------------------------------------------------------

    @IsTest
    static void setQuantityPerTemplateRejectsValuesBelowOne() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP).setQuantityPerTemplate(0);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('makes no sense'), ex.getMessage());
        }
    }

    @IsTest
    static void withVariantPinsAMatchingKeyAndGenerates() {
        Contact result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .withVariant(XFTY_LookupKey.get(Contact.SObjectType))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();

        Assert.isNotNull(result.Id);
        Assert.isTrue(result.LastName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void withVariantRejectsANullKey() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP).withVariant(null);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('variant key is required'), ex.getMessage());
        }
    }

    @IsTest
    static void withVariantRejectsAKeyForAnotherSObjectType() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .withVariant(XFTY_LookupKey.get(Account.SObjectType));
            Assert.fail('Expected a ConflictException');
        } catch (XFTY_DummySObjectProvider.ConflictException ex) {
            Assert.isTrue(ex.getMessage().contains('Account'), ex.getMessage());
            Assert.isTrue(ex.getMessage().contains('Contact'), ex.getMessage());
        }
    }

    @IsTest
    static void withVariantRejectsALateCallAfterPut() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .put(Contact.FirstName, 'x')
                    .withVariant(XFTY_LookupKey.get(Contact.SObjectType));
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('withVariant'), ex.getMessage());
        }
    }

    @IsTest
    static void overrideTemplateListRejectsMixedSObjectTypes() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplateList(new List<SObject>{ new Contact(), new Account() });
            Assert.fail('Expected a ConflictException');
        } catch (XFTY_DummySObjectProvider.ConflictException ex) {
            Assert.isTrue(ex.getMessage().contains('is not matched by template'), ex.getMessage());
        }
    }

    @IsTest
    static void setOverrideTemplateListToleratesNullAndEmpty() {
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(null)
                .setOverrideTemplateList(new List<SObject>())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.isNotNull(result.Id, 'A blank template is generated when no overrides are supplied');
    }

    // put(...) routing -----------------------------------------------------

    @IsTest
    static void putRoutesAValueStrategyPassedAsObject() {
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, (Object) new XFTY_DummyDefaultValueExact('RoutedStrategy'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('RoutedStrategy', result.FirstName);
    }

    @IsTest
    static void putRoutesAContextAwareStrategyPassedAsObject() {
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, 'Source')
                .put(Contact.Department, (Object) new XFTY_CopyFromSibling(Contact.FirstName))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('Source', result.Department, 'a context-aware strategy passed as Object still routes correctly');
    }

    @IsTest
    static void putRejectsARelationship() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .put(Contact.AccountId, (Object) new XFTY_DummyDefaultRelationship(new Account()));
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('putRequired'), ex.getMessage());
        }
    }

    @IsTest
    static void putOptionalAddsAnOptionalRelationshipThatRequiredInclusivitySkips() {
        XFTY_DummySObjectBundle underRequired;
        XFTY_DummySObjectBundle underAll;
        Test.startTest();
        System.runAs(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER) {
            underRequired = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()))
                    .removeFromMasterTemplate(Contact.AccountId)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            underAll = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()))
                    .removeFromMasterTemplate(Contact.AccountId)
                    .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }
        Test.stopTest();

        Assert.isNull(underRequired.getList(Contact.ReportsToId), 'optional relationship skipped for REQUIRED');
        Assert.areEqual(1, underAll.getList(Contact.ReportsToId).size(), 'optional relationship generated for ALL');
    }

    // includeOptional / excludeRelationship -------------------------------------

    @IsTest
    static void includeOptionalGeneratesJustThatOptionalRelationshipUnderRequired() {
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        System.runAs(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()))
                    .includeOptional(Contact.ReportsToId)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }
        Test.stopTest();

        Assert.areEqual(1, bundle.getList(Contact.ReportsToId).size(), 'the included optional relationship is generated');
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the required Account is still generated');
    }

    @IsTest
    static void includeOptionalOnAnAlreadyRequiredRelationshipIsANoOp() {
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        System.runAs(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .includeOptional(Contact.AccountId) // already required - nothing to promote
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }
        Test.stopTest();

        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the required Account is generated, exactly once');
    }

    @IsTest
    static void includeOptionalRejectsAFieldThatIsNotARelationship() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .includeOptional(Contact.FirstName) // not a relationship
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('is not a relationship'), ex.getMessage());
        }
    }

    @IsTest
    static void excludeRelationshipSkipsARequiredRelationship() {
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        System.runAs(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .excludeRelationship(Contact.AccountId)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }
        Test.stopTest();

        Assert.isNull(bundle.getList(Contact.AccountId), 'the excluded relationship is not generated');
        Contact contact = (Contact) bundle.getList(Contact.Id)[0];
        Assert.isNull(contact.AccountId, 'and not left as an orphan reference');
    }

    @IsTest
    static void excludeRelationshipIsInstanceLocal() {
        XFTY_DummySObjectBundle excluded;
        XFTY_DummySObjectBundle normal;
        Test.startTest();
        System.runAs(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER) {
            excluded = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .excludeRelationship(Contact.AccountId)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            normal = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }
        Test.stopTest();

        Assert.isNull(excluded.getList(Contact.AccountId));
        Assert.areEqual(1, normal.getList(Contact.AccountId).size(),
                'a separate Provider on the same lookup still generates the relationship');
    }

    @IsTest
    static void excludeRelationshipRejectsAPlainValueField() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .excludeRelationship(Contact.FirstName);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('no relationship'), ex.getMessage());
        }
    }

    // supply / supplyList / supplyBundle -------------------------------------

    @IsTest
    static void supplyReturnsASingleRecordWithMasterTemplateDefaults() {
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.isNotNull(result.Id);
        Assert.isTrue(result.FirstName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_FIRST_NAME_PREFIX));
        Assert.isTrue(result.LastName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void supplyListHonoursOverrideTemplatesAndQuantity() {
        List<SObject> results;
        Test.startTest();
        results = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(new List<SObject>{
                        new Contact(FirstName = 'Alice'),
                        new Contact(FirstName = 'Bob')
                })
                .setQuantityPerTemplate(2)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        Assert.areEqual(4, results.size(), 'Two templates x quantity 2');
        List<String> firstNames = new List<String>();
        for (SObject record : results) {
            firstNames.add((String) record.get(Contact.FirstName));
        }
        // Quantity is applied outside the template loop: A, B, A, B (not A, A, B, B).
        Assert.areEqual(new List<String>{ 'Alice', 'Bob', 'Alice', 'Bob' }, firstNames);
    }

    // Customization: put(...) / removeFromMasterTemplate(...) ---------------

    @IsTest
    static void putReplacesTheGenerationStrategyForAField() {
        // Regression guard: a defect previously made provider-level put(...) a no-op.
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, new XFTY_DummyDefaultValueExact('DeliberateName'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('DeliberateName', result.FirstName);
    }

    @IsTest
    static void putAcceptsABareLiteralAndTreatsItAsExact() {
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, 'LiteralFirstName')
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('LiteralFirstName', result.FirstName);
    }

    @IsTest
    static void removeFromMasterTemplateDropsAGeneratedValue() {
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .removeFromMasterTemplate(Contact.Email)
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
                .supply();
        Test.stopTest();

        Assert.isNull(result.Email, 'Email should no longer be generated once removed');
        Assert.isNotNull(result.LastName, 'Other defaults are unaffected');
    }

    @IsTest
    static void customizingOneProviderDoesNotLeakIntoTheNext() {
        // Because the master template is now copied rather than shallow-cloned,
        // a customization on one provider must not affect a later, separate one.
        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, new XFTY_DummyDefaultValueExact('Customized'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();

        Contact pristine = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.isTrue(
                pristine.FirstName.startsWith(XFTY_DefaultContactDataProvider.DEFAULT_FIRST_NAME_PREFIX),
                'Expected the default prefix, got: ' + pristine.FirstName
        );
    }

    @IsTest
    static void overrideTemplateWinsOverPut() {
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, new XFTY_DummyDefaultValueExact('FromPut'))
                .setOverrideTemplate(new Contact(FirstName = 'FromOverride'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('FromOverride', result.FirstName);
    }
}
