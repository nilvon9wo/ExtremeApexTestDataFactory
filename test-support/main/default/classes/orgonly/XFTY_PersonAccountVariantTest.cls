/**
 * Exercises the record-type Provider-variant mechanism end to end using a real
 * Person Account (the scratch org enables the feature; the published package does
 * not require it). NOW mode - real DML, so `System.runAs`.
 */
@IsTest
private class XFTY_PersonAccountVariantTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final XFTY_LookupKeyIntf PERSON_ACCOUNT =
            XFTY_RecordTypeLookupKey.get(Account.SObjectType, XFTY_PersonAccountDataProvider.RECORD_TYPE_DEVELOPER_NAME);

    private static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                PERSON_ACCOUNT => new XFTY_PersonAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
        });
    }

    private static Id personRtId() {
        return XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'PersonAccount');
    }

    @IsTest
    static void testGetMasterTemplate_forThePersonAccountProvider_pinsThePersonAccountRecordType() {
        // Arrange
        XFTY_PersonAccountDataProvider provider = new XFTY_PersonAccountDataProvider();

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = provider.getMasterTemplate();
        Test.stopTest();

        // Assert
        Assert.areEqual(Account.Id, provider.getPrimaryTargetField());
        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Account.RecordTypeId));
        Assert.areEqual(personRtId(), template.defaultBySObjectFieldMap.get(Account.RecordTypeId).get());
    }

    @IsTest
    static void testWithVariant_forThePersonAccountKey_generatesAPersonAccount() {
        assertGeneratesPersonAccount(
                new XFTY_DummySObjectProvider(Account.SObjectType, lookup()).withVariant(PERSON_ACCOUNT)
        );
    }

    @IsTest
    static void testConstructor_fromThePersonAccountKey_generatesAPersonAccount() {
        assertGeneratesPersonAccount(new XFTY_DummySObjectProvider(PERSON_ACCOUNT, lookup()));
    }

    @IsTest
    static void testConstructor_fromATemplateCarryingThePersonRecordType_generatesAPersonAccount() {
        assertGeneratesPersonAccount(
                new XFTY_DummySObjectProvider(new Account(RecordTypeId = personRtId()), lookup())
        );
    }

    @IsTest
    static void testSetOverrideTemplate_carryingThePersonRecordType_generatesAPersonAccount() {
        assertGeneratesPersonAccount(
                new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                        .setOverrideTemplate(new Account(RecordTypeId = personRtId()))
        );
    }

    @IsTest
    static void testSupply_withoutAnyPersonVariantSignal_usesTheDefaultBusinessAccountProvider() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.NOW);

        // Act
        Account business;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            business = (Account) provider.supply();
            Test.stopTest();
        }

        // Assert
        Account reloaded = [SELECT IsPersonAccount, Industry FROM Account WHERE Id = :business.Id];
        Assert.isFalse(reloaded.IsPersonAccount);
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_INDUSTRY, reloaded.Industry);
    }

    // Runner --------------------------------------------

    static void assertGeneratesPersonAccount(XFTY_DummySObjectProvider provider) {
        // Arrange - the caller supplies a provider configured to pick the Person Account variant
        provider.setInsertMode(XFTY_InsertModeEnum.NOW);

        // Act
        Account person;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            person = (Account) provider.supply();
            Test.stopTest();
        }

        // Assert
        Assert.isTrue([SELECT IsPersonAccount FROM Account WHERE Id = :person.Id].IsPersonAccount,
                'the generated record is a Person Account');
    }
}
