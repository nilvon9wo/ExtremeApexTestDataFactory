/**
 * Exercises the record-type Provider-variant mechanism end to end using a real
 * Person Account (the scratch org enables the feature; the published package
 * does not require it).
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

    @IsTest
    static void theProviderExposesAPersonAccountMasterTemplate() {
        XFTY_PersonAccountDataProvider provider = new XFTY_PersonAccountDataProvider();
        Assert.areEqual(Account.Id, provider.getPrimaryTargetField());

        XFTY_DummySObjectMasterTemplate template = provider.getMasterTemplate();
        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Account.RecordTypeId));
        Assert.areEqual(
                XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'PersonAccount'),
                template.defaultBySObjectFieldMap.get(Account.RecordTypeId).get()
        );
    }

    @IsTest
    static void withVariantSelectsThePersonAccountProvider() {
        Account person;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            person = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                    .withVariant(PERSON_ACCOUNT)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
        }
        Test.stopTest();

        Account reloaded = [SELECT IsPersonAccount, LastName FROM Account WHERE Id = :person.Id];
        Assert.isTrue(reloaded.IsPersonAccount, 'the generated record is a Person Account');
        Assert.isTrue(reloaded.LastName.startsWith(XFTY_PersonAccountDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @IsTest
    static void theLookupKeyConstructorSelectsThePersonAccountProvider() {
        Account person;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            person = (Account) new XFTY_DummySObjectProvider(PERSON_ACCOUNT, lookup())
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
        }
        Test.stopTest();

        Assert.isTrue([SELECT IsPersonAccount FROM Account WHERE Id = :person.Id].IsPersonAccount);
    }

    @IsTest
    static void theTemplateConstructorDerivesTypeAndPersonVariantFromTheRecordType() {
        Id personRtId = XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'PersonAccount');

        Account person;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            person = (Account) new XFTY_DummySObjectProvider(new Account(RecordTypeId = personRtId), lookup())
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
        }
        Test.stopTest();

        Assert.isTrue([SELECT IsPersonAccount FROM Account WHERE Id = :person.Id].IsPersonAccount);
    }

    @IsTest
    static void anOverrideTemplateCarryingThePersonRecordTypeSelectsThePersonProvider() {
        Id personRtId = XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'PersonAccount');

        Account person;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            person = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                    .setOverrideTemplate(new Account(RecordTypeId = personRtId))
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
        }
        Test.stopTest();

        Assert.isTrue([SELECT IsPersonAccount FROM Account WHERE Id = :person.Id].IsPersonAccount);
    }

    @IsTest
    static void aBusinessAccountStillUsesTheDefaultProvider() {
        Account business;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            business = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
        }
        Test.stopTest();

        Account reloaded = [SELECT IsPersonAccount, Industry FROM Account WHERE Id = :business.Id];
        Assert.isFalse(reloaded.IsPersonAccount);
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_INDUSTRY, reloaded.Industry);
    }
}
