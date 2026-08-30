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
            new XFTY_DummySObjectProvider(null, LOOKUP);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('SObjectType to request data'), ex.getMessage());
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
    static void overrideTemplateListRejectsMixedSObjectTypes() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplateList(new List<SObject>{ new Contact(), new Account() });
            Assert.fail('Expected a ConflictException');
        } catch (XFTY_DummySObjectProvider.ConflictException ex) {
            Assert.isTrue(ex.getMessage().contains('is not matched by template'), ex.getMessage());
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
