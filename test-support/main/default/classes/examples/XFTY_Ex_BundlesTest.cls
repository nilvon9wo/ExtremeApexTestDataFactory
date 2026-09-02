/**
 * Runnable proof for docs/use/bundles.md - every `@IsTest` method is one fenced
 * example from that page.
 */
@IsTest
private class XFTY_Ex_BundlesTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void testSupplyBundle_exposesEveryGeneratedRecordWithoutSoql() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.Id).size());
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the generated Account, no SOQL');
    }

    @IsTest
    static void testGetList_staysAlignedOneToOneWithThePrimaryRecords() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setQuantityPerTemplate(3)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        Test.stopTest();

        // Assert - entry i of getList(AccountId) is the Account for entry i of getList(Id)
        List<Contact> contacts = (List<Contact>) bundle.getList(Contact.Id);
        List<Account> accounts = (List<Account>) bundle.getList(Contact.AccountId);
        Assert.areEqual(3, contacts.size());
        Assert.areEqual(3, accounts.size());
        for (Integer row = 0; row < contacts.size(); row++) {
            Assert.areEqual(accounts[row].Id, contacts[row].AccountId, 'row ' + row + ' aligns');
        }
    }

    private static final XFTY_LookupKeyIntf MID_ACCOUNT_KEY = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'mid');

    @IsTest
    static void testGetBundle_navigatesTheGraphAsDeepAsItNests() {
        // Arrange - a Contact whose Account is generated with a (flat) parent Account of its own
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactUnderNestedAccount(),
                        MID_ACCOUNT_KEY => new AccountWithParent(),
                        XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider()
                }
        );

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        Test.stopTest();

        // Assert
        XFTY_DummySObjectBundle accountBundle = bundle.getBundle(Contact.AccountId);
        XFTY_DummySObjectBundle parentAccountBundle = accountBundle.getBundle(Account.ParentId);
        Assert.isNotNull(accountBundle, 'the Account sub-bundle');
        Assert.isNotNull(parentAccountBundle, 'and its parent Account sub-bundle');
        Account childAccount = (Account) accountBundle.getList(Account.Id)[0];
        Account parentAccount = (Account) parentAccountBundle.getList(Account.Id)[0];
        Assert.areEqual(parentAccount.Id, childAccount.ParentId, 'the nested Account is wired to its parent');
    }

    @IsTest
    static void testGetValue_walksAnAncestorPathWithoutHoldingTheIntermediateBundles() {
        // Arrange - a Contact with its generated parent Account
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();

        // Act
        Object parentAccountName = bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name });

        // Assert - same value as the long-hand navigation
        Account parentAccount = (Account) bundle.getList(Contact.AccountId)[0];
        Assert.areEqual(parentAccount.Name, parentAccountName);
    }

    @IsTest
    static void testGetValue_whenAHopWasNotGenerated_returnsNull() {
        // Arrange - NONE inclusivity, so the Account is never generated
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                .supplyBundle();

        // Act
        Object missing = bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name });

        // Assert
        Assert.isNull(missing, 'an ungenerated hop reads as null, no exception');
    }

    @IsTest
    static void testGetChildList_exposesGeneratedChildrenByRelationshipField() {
        // Arrange - an Account with three Contacts hung below it
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();

        // Act
        List<Contact> children = (List<Contact>) bundle.getChildList(Contact.AccountId);

        // Assert
        Account parentAccount = (Account) bundle.primaryRecords()[0];
        Assert.areEqual(3, children.size());
        Assert.areEqual(parentAccount.Id, children[0].AccountId, 'each child points back at the primary');
    }

    @IsTest
    static void testChildRecordsOf_keepsEachPrimaryLinedUpWithItsOwnChildren() {
        // Arrange - two Accounts, three Contacts hung below each
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setQuantityPerTemplate(2)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();

        // Act
        List<SObject> secondAccountsContacts = bundle.childRecordsOf(1, Contact.AccountId);

        // Assert
        Account secondAccount = (Account) bundle.primaryRecords()[1];
        Assert.areEqual(3, secondAccountsContacts.size(), 'exactly the slice for that primary row');
        for (SObject childContact : secondAccountsContacts) {
            Assert.areEqual(secondAccount.Id, childContact.get(Contact.AccountId), 'all belong to primary row 1');
        }
    }

    // Fixture ---------------------------------------------------------------

    private class ContactUnderNestedAccount implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_IncrementingStringExpression('Leaf'))
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(MID_ACCOUNT_KEY, new Account()));

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

    private class AccountWithParent implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_IncrementingStringExpression('Acct'))
                .putRequired(Account.ParentId, new XFTY_DummyDefaultRelationship(new Account()));

        public SObjectField getPrimaryTargetField() {
            return Account.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }
}
