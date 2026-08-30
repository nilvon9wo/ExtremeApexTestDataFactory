/**
 * Coverage for context-aware value generation: the second value pass in
 * `XFTY_DummySObjectFactory`, `XFTY_CopyFromSibling`, `XFTY_CopyFromAncestor`, and
 * a custom `XFTY_ContextAwareValueIntf` implementation.
 *
 * See docs/design/context-aware-values.md.
 */
@IsTest
private class XFTY_ContextAwareValueTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // --- XFTY_CopyFromSibling ------------------------------------------------

    @IsTest
    static void copyFromSiblingTakesAPlainSiblingValue() {
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.ShippingCity, 'Berlin')
                .put(Account.BillingCity, new XFTY_CopyFromSibling(Account.ShippingCity))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('Berlin', result.ShippingCity);
        Assert.areEqual('Berlin', result.BillingCity, 'BillingCity copied from the ShippingCity sibling');
    }

    @IsTest
    static void copyFromSiblingSeesAnEarlierContextAwareSibling() {
        // put order: ShippingCity (plain) -> BillingCity (context-aware, reads ShippingCity)
        //            -> ShippingStreet (context-aware, reads BillingCity)
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.ShippingCity, 'Munich')
                .put(Account.BillingCity, new XFTY_CopyFromSibling(Account.ShippingCity))
                .put(Account.BillingStreet, new XFTY_CopyFromSibling(Account.BillingCity))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('Munich', result.BillingCity);
        Assert.areEqual('Munich', result.BillingStreet, 'a context-aware value reads an earlier context-aware sibling');
    }

    @IsTest
    static void copyFromSiblingDoesNotOverrideAValueTheTestSupplied() {
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.ShippingCity, 'Hamburg')
                .put(Account.BillingCity, new XFTY_CopyFromSibling(Account.ShippingCity))
                .setOverrideTemplate(new Account(BillingCity = 'Explicit'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('Explicit', result.BillingCity, 'the override template still wins');
    }

    @IsTest
    static void copyFromSiblingRejectsANullField() {
        try {
            new XFTY_CopyFromSibling(null);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('source field'), ex.getMessage());
        }
    }

    @IsTest
    static void aContextAwareValueGetWithNoContextThrows() {
        try {
            new XFTY_CopyFromSibling(Account.Name).get();
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('context-aware'), ex.getMessage());
        }
        try {
            new XFTY_CopyFromAncestor(Contact.AccountId, Account.Name).get();
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('context-aware'), ex.getMessage());
        }
    }

    // --- XFTY_CopyFromAncestor ---------------------------------------------

    @IsTest
    static void copyFromAncestorTakesAFieldFromTheGeneratedParent() {
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account(Name = 'Wired Parent')))
                    .put(Contact.Department, new XFTY_CopyFromAncestor(Contact.AccountId, Account.Name))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        Assert.areEqual('Wired Parent', result.Department, 'Department copied from the generated Account.Name');
    }

    @IsTest
    static void copyFromAncestorIsNullWhenTheRelationshipWasNotGenerated() {
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .removeFromMasterTemplate(Contact.AccountId)
                    .put(Contact.Department, new XFTY_CopyFromAncestor(Contact.AccountId, Account.Name))
                    .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        Assert.isNull(result.Department, 'no ancestor generated -> null');
    }

    @IsTest
    static void copyFromAncestorAppliesPerRowWithQuantity() {
        List<SObject> results;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            results = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    // the bundled Account Provider gives each generated Account an incrementing Name
                    .put(Contact.Department, new XFTY_CopyFromAncestor(Contact.AccountId, Account.Name))
                    .setQuantityPerTemplate(3)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyList();
            Test.stopTest();
        }

        Set<String> departments = new Set<String>();
        for (SObject c : results) {
            departments.add((String) c.get(Contact.Department));
        }
        Assert.areEqual(3, departments.size(), 'each Contact copied its own row Account name');
    }

    @IsTest
    static void copyFromAncestorIsNullWhenHandedAContextWithNoAncestors() {
        // a base context (not scoped to a record) has no ancestor bundle
        Object value = new XFTY_CopyFromAncestor(Contact.AccountId, Account.Name)
                .get(new XFTY_GenerationContext(LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE));

        Assert.isNull(value);
    }

    @IsTest
    static void copyFromAncestorRejectsNullFields() {
        try {
            new XFTY_CopyFromAncestor(null, Account.Name);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('relationship field'), ex.getMessage());
        }
    }

    // --- a custom context-aware strategy ----------------------------------

    @IsTest
    static void aCustomContextAwareStrategyCanDeriveFromASibling() {
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.Birthdate, Date.newInstance(2010, 1, 1))
                .put(Contact.Description, new IsMinorFlag(Contact.Birthdate))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('MINOR', result.Description);
    }

    /** Derives a MINOR / ADULT flag from a Date sibling - the kind of logic XFTY leaves to consumers. */
    private class IsMinorFlag implements XFTY_ContextAwareValueIntf {
        private final SObjectField birthdateField;
        private IsMinorFlag(SObjectField birthdateField) {
            this.birthdateField = birthdateField;
        }
        public Object get(XFTY_GenerationContext context) {
            Date birthdate = (Date) context.recordBeingBuilt.get(this.birthdateField);
            return (birthdate != null && birthdate.addYears(18) > Date.today()) ? 'MINOR' : 'ADULT';
        }
        public Object get() {
            throw new XFTY_DummySObjectFtyProviderException('context-aware');
        }
    }

    // --- bundleSoFar sees the sibling primary records --------------------

    @IsTest
    static void aContextAwareValueSeesTheSiblingPrimaryRecordsInBundleSoFar() {
        List<SObject> accounts = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.Description, new SiblingCountLabel())
                .setQuantityPerTemplate(3)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();

        Assert.areEqual(3, accounts.size());
        Set<Object> labels = new Set<Object>();
        for (SObject generated : accounts) {
            labels.add(generated.get(Account.Description));
        }
        Assert.areEqual(
                new Set<Object>{ '1 of 3', '2 of 3', '3 of 3' }, labels,
                'each row sees all three sibling primaries (the pass runs after every one is built) and its own rowIndex'
        );
    }

    /** Reads the whole batch of sibling primary records out of `bundleSoFar`. */
    private class SiblingCountLabel implements XFTY_ContextAwareValueIntf {
        public Object get(XFTY_GenerationContext context) {
            Integer siblingCount = context.bundleSoFar.getList(Account.Id).size();
            return (context.rowIndex + 1) + ' of ' + siblingCount;
        }
        public Object get() {
            throw new XFTY_DummySObjectFtyProviderException('context-aware');
        }
    }
}
