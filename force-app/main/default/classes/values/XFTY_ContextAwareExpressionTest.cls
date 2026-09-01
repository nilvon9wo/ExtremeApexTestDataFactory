/**
 * Coverage for context-aware value generation: the second value pass in
 * `XFTY_DummySObjectFactory`, `XFTY_CopyFromSiblingExpression`, `XFTY_CopyFromAncestorExpression`, and
 * a custom `XFTY_ContextAwareExpressionIntf` implementation.
 *
 * See docs/roadmap/context-aware-values.md.
 */
@IsTest
private class XFTY_ContextAwareExpressionTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // --- XFTY_CopyFromSiblingExpression ------------------------------------------------

    @IsTest
    static void copyFromSiblingTakesAPlainSiblingValue() {
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.ShippingCity, 'Berlin')
                .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
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
                .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
                .put(Account.BillingStreet, new XFTY_CopyFromSiblingExpression(Account.BillingCity))
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
                .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
                .setOverrideTemplate(new Account(BillingCity = 'Explicit'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.areEqual('Explicit', result.BillingCity, 'the override template still wins');
    }

    @IsTest
    static void copyFromSiblingRejectsANullField() {
        try {
            new XFTY_CopyFromSiblingExpression(null);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('source field'), ex.getMessage());
        }
    }

    @IsTest
    static void aContextAwareStrategyIsNotAPlainValueStrategy() {
        // B, not A: XFTY_ContextAwareExpressionIntf does not extend XFTY_ValueExpressionIntf,
        // so there is no misleading no-arg get() to call.
        Object expression = new XFTY_CopyFromSiblingExpression(Account.Name);
        Assert.isFalse(expression instanceof XFTY_ValueExpressionIntf);
        Assert.isTrue(expression instanceof XFTY_ContextAwareExpressionIntf);
    }

    @IsTest
    static void copyFromSiblingRejectsAContextAwareSiblingThatIsPutAfterIt() {
        // Description (reader) is put before Site (a context-aware value it reads).
        try {
            new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .put(Account.Description, new XFTY_CopyFromSiblingExpression(Account.Site))
                    .put(Account.Site, new XFTY_CopyFromSiblingExpression(Account.AccountNumber))
                    .put(Account.AccountNumber, 'seed')
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Assert.fail('Expected an exception - Site is a context-aware value put after its reader');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('Site'), ex.getMessage());
            Assert.isTrue(ex.getMessage().contains('has not been generated yet'), ex.getMessage());
            Assert.isTrue(ex.getMessage().contains('before'), ex.getMessage());
        }
    }

    @IsTest
    static void copyFromSiblingRejectsACircularSiblingReference() {
        try {
            new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .put(Account.Description, new XFTY_CopyFromSiblingExpression(Account.Site))
                    .put(Account.Site, new XFTY_CopyFromSiblingExpression(Account.Description))
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Assert.fail('Expected an exception - Description and Site copy from each other');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('has not been generated yet'), ex.getMessage());
        }
    }

    @IsTest
    static void copyFromSiblingTellsAGeneratedNullApartFromANotYetGeneratedSibling() {
        // Site is context-aware and generates to null; Description reads it, put
        // AFTER it - so the read is legal and simply yields null, no exception.
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.Site, new AlwaysNull())
                .put(Account.Description, new XFTY_CopyFromSiblingExpression(Account.Site))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.isNull(result.Site, 'the sibling genuinely generated to null');
        Assert.isNull(result.Description, 'copying a generated-null sibling yields null - and does not throw');
    }

    @IsTest
    static void copyFromSiblingCanOnlyRunInsideTheValuePass() {
        try {
            new XFTY_CopyFromSiblingExpression(Account.Name).get(
                    new XFTY_GenerationContext(LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE)
            );
            Assert.fail('Expected an exception - there is no record being built');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('context-aware value is being generated'), ex.getMessage());
        }
    }

    /** A context-aware expression whose generated value is legitimately null. */
    private class AlwaysNull implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            return null;
        }
    }

    // --- XFTY_CopyFromAncestorExpression ---------------------------------------------

    @IsTest
    static void copyFromAncestorTakesAFieldFromTheGeneratedParent() {
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account(Name = 'Wired Parent')))
                    .put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Name))
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
                    .put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Name))
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
                    .put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Name))
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
        Object value = new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Name)
                .get(new XFTY_GenerationContext(LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE));

        Assert.isNull(value);
    }

    @IsTest
    static void copyFromAncestorRejectsANullPathStep() {
        try {
            new XFTY_CopyFromAncestorExpression(null, Account.Name);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('cannot be null'), ex.getMessage());
        }
    }

    @IsTest
    static void copyFromAncestorRejectsATooShortPath() {
        try {
            new XFTY_CopyFromAncestorExpression(new List<SObjectField>{ Account.Name });
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('at least one relationship field'), ex.getMessage());
        }
    }

    @IsTest
    static void copyFromAncestorFollowsAMultiHopPath() {
        // Contact -> Account -> Owner(User).  Copy the generated Owner's Alias onto the Contact.
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountWithOwnerProvider(),
                        XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
                }
        );

        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                    .put(Contact.Department, new XFTY_CopyFromAncestorExpression(new List<SObjectField>{
                            Contact.AccountId, Account.OwnerId, User.Alias
                    }))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        Assert.isNotNull(result.Department, 'the Account Owner Alias was copied two hops up');
    }

    /** An Account Provider that generates an Owner, so multi-hop tests have a second level. */
    private class AccountWithOwnerProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_IncrementingStringExpression('Acct'))
                .putRequired(Account.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
        public SObjectField getPrimaryTargetField() {
            return Account.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    // --- a custom context-aware expression ----------------------------------

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
    private class IsMinorFlag implements XFTY_ContextAwareExpressionIntf {
        private final SObjectField birthdateField;
        private IsMinorFlag(SObjectField birthdateField) {
            this.birthdateField = birthdateField;
        }
        public Object get(XFTY_GenerationContext context) {
            Date birthdate = (Date) context.recordBeingBuilt.get(this.birthdateField);
            return (birthdate != null && birthdate.addYears(18) > Date.today()) ? 'MINOR' : 'ADULT';
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
    private class SiblingCountLabel implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            Integer siblingCount = context.bundleSoFar.getList(Account.Id).size();
            return (context.rowIndex + 1) + ' of ' + siblingCount;
        }
    }
}
