/**
 * Proves context-aware value generation: the second value pass in
 * `XFTY_DummySObjectFactory`, `XFTY_CopyFromSiblingExpression`,
 * `XFTY_CopyFromAncestorExpression`, and a custom `XFTY_ContextAwareExpressionIntf`.
 * MOCK mode throughout - no DML/SOQL, so no `System.runAs`.
 *
 * See docs/roadmap/context-aware-values.md.
 */
@IsTest
private class XFTY_ContextAwareExpressionTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    private static XFTY_DummySObjectProvider accountProvider() {
        return new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP).setInsertMode(XFTY_InsertModeEnum.MOCK);
    }

    private static XFTY_DummySObjectProvider contactProvider() {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP).setInsertMode(XFTY_InsertModeEnum.MOCK);
    }

    // XFTY_CopyFromSiblingExpression ----------------------------

    @IsTest
    static void testGet_forACopyFromSibling_takesTheSiblingsPlainValue() {
        // Arrange
        XFTY_DummySObjectProvider provider = accountProvider()
                .put(Account.ShippingCity, 'Berlin')
                .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity));

        // Act
        Test.startTest();
        Account result = (Account) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Berlin', result.BillingCity, 'BillingCity copied from the ShippingCity sibling');
    }

    @IsTest
    static void testGet_forACopyFromSibling_seesAnEarlierContextAwareSibling() {
        // Arrange - ShippingCity (plain) -> BillingCity (reads ShippingCity) -> BillingStreet (reads BillingCity)
        XFTY_DummySObjectProvider provider = accountProvider()
                .put(Account.ShippingCity, 'Munich')
                .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
                .put(Account.BillingStreet, new XFTY_CopyFromSiblingExpression(Account.BillingCity));

        // Act
        Test.startTest();
        Account result = (Account) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Munich', result.BillingStreet, 'a context-aware value reads an earlier context-aware sibling');
    }

    @IsTest
    static void testGet_forACopyFromSibling_doesNotOverrideAValueTheOverrideTemplateSupplied() {
        // Arrange
        XFTY_DummySObjectProvider provider = accountProvider()
                .put(Account.ShippingCity, 'Hamburg')
                .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
                .setOverrideTemplate(new Account(BillingCity = 'Explicit'));

        // Act
        Test.startTest();
        Account result = (Account) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Explicit', result.BillingCity, 'the override template still wins');
    }

    @IsTest
    static void testGet_forACopyFromSibling_whenTheSiblingGeneratesToNull_yieldsNullWithoutThrowing() {
        // Arrange - Site is context-aware and generates to null; Description reads it, put AFTER it
        XFTY_DummySObjectProvider provider = accountProvider()
                .put(Account.Site, new AlwaysNull())
                .put(Account.Description, new XFTY_CopyFromSiblingExpression(Account.Site));

        // Act
        Test.startTest();
        Account result = (Account) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isNull(result.Site, 'the sibling genuinely generated to null');
        Assert.isNull(result.Description, 'copying a generated-null sibling yields null - and does not throw');
    }

    @IsTest
    static void testConstructor_forACopyFromSibling_whenTheFieldIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            new XFTY_CopyFromSiblingExpression(null);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('source field'), thrown.getMessage());
    }

    @IsTest
    static void testType_forACopyFromSibling_isAContextAwareExpressionNotAPlainValueExpression() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        Object expression = new XFTY_CopyFromSiblingExpression(Account.Name);
        Test.stopTest();

        // Assert - B, not A: no misleading no-arg get() to call
        Assert.isFalse(expression instanceof XFTY_ValueExpressionIntf);
        Assert.isTrue(expression instanceof XFTY_ContextAwareExpressionIntf);
    }

    @IsTest
    static void testGet_forACopyFromSibling_whenTheSiblingItReadsIsPutAfterIt_throws() {
        // Arrange - Description (reader) is put before Site (a context-aware value it reads)
        XFTY_DummySObjectProvider provider = accountProvider()
                .put(Account.Description, new XFTY_CopyFromSiblingExpression(Account.Site))
                .put(Account.Site, new XFTY_CopyFromSiblingExpression(Account.AccountNumber))
                .put(Account.AccountNumber, 'seed');

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            provider.supply();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Site'), thrown.getMessage());
        Assert.isTrue(thrown.getMessage().contains('has not been generated yet'), thrown.getMessage());
        Assert.isTrue(thrown.getMessage().contains('before'), thrown.getMessage());
    }

    @IsTest
    static void testGet_forACopyFromSibling_whenTwoSiblingsReadEachOther_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = accountProvider()
                .put(Account.Description, new XFTY_CopyFromSiblingExpression(Account.Site))
                .put(Account.Site, new XFTY_CopyFromSiblingExpression(Account.Description));

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            provider.supply();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('has not been generated yet'), thrown.getMessage());
    }

    @IsTest
    static void testGet_forACopyFromSibling_whenRunOutsideTheValuePass_throws() {
        // Arrange
        XFTY_GenerationContext baseContext =
                new XFTY_GenerationContext(LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            new XFTY_CopyFromSiblingExpression(Account.Name).get(baseContext);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'there is no record being built');
        Assert.isTrue(thrown.getMessage().contains('context-aware value is being generated'), thrown.getMessage());
    }

    // XFTY_CopyFromAncestorExpression --------------------------

    @IsTest
    static void testGet_forACopyFromAncestor_takesAFieldFromTheGeneratedParent() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider()
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account(Name = 'Wired Parent')))
                .put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Name))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Wired Parent', result.Department, 'Department copied from the generated Account.Name');
    }

    @IsTest
    static void testGet_forACopyFromAncestor_whenTheRelationshipWasNotGenerated_isNull() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider()
                .removeFromMasterTemplate(Contact.AccountId)
                .put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Name))
                .setInclusivity(XFTY_InsertInclusivityEnum.NONE);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isNull(result.Department, 'no ancestor generated -> null');
    }

    @IsTest
    static void testGet_forACopyFromAncestor_withQuantity_appliesPerRow() {
        // Arrange - the bundled Account Provider gives each generated Account an incrementing Name
        XFTY_DummySObjectProvider provider = contactProvider()
                .put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Name))
                .setQuantityPerTemplate(3)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED);

        // Act
        Test.startTest();
        List<SObject> results = provider.supplyList();
        Test.stopTest();

        // Assert
        Set<Object> departments = new Set<Object>();
        for (SObject contactRecord : results) {
            departments.add(contactRecord.get(Contact.Department));
        }
        Assert.areEqual(3, departments.size(), 'each Contact copied its own row Account name');
    }

    @IsTest
    static void testGet_forACopyFromAncestor_whenHandedABaseContextWithNoAncestors_isNull() {
        // Arrange
        XFTY_GenerationContext baseContext =
                new XFTY_GenerationContext(LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);

        // Act
        Test.startTest();
        Object value = new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Name).get(baseContext);
        Test.stopTest();

        // Assert
        Assert.isNull(value);
    }

    @IsTest
    static void testConstructor_forACopyFromAncestor_whenAPathStepIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            new XFTY_CopyFromAncestorExpression(null, Account.Name);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('cannot be null'), thrown.getMessage());
    }

    @IsTest
    static void testConstructor_forACopyFromAncestor_whenThePathIsTooShort_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            new XFTY_CopyFromAncestorExpression(new List<SObjectField>{ Account.Name });
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('at least one relationship field'), thrown.getMessage());
    }

    @IsTest
    static void testGet_forACopyFromAncestor_followsAMultiHopPath() {
        // Arrange - Contact -> Account -> Owner(User); copy the generated Owner's Alias onto the Contact
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountWithOwnerProvider(),
                        XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
                }
        );
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .put(Contact.Department, new XFTY_CopyFromAncestorExpression(new List<SObjectField>{
                        Contact.AccountId, Account.OwnerId, User.Alias
                }))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.Department, 'the Account Owner Alias was copied two hops up');
    }

    // A custom context-aware expression -----------------------

    @IsTest
    static void testGet_forACustomContextAwareExpression_canDeriveFromASibling() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider()
                .put(Contact.Birthdate, Date.newInstance(2010, 1, 1))
                .put(Contact.Description, new IsMinorFlag(Contact.Birthdate));

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('MINOR', result.Description);
    }

    @IsTest
    static void testGet_forACustomContextAwareExpression_seesTheSiblingPrimaryRecordsInBundleSoFar() {
        // Arrange
        XFTY_DummySObjectProvider provider = accountProvider()
                .put(Account.Description, new SiblingCountLabel())
                .setQuantityPerTemplate(3);

        // Act
        Test.startTest();
        List<SObject> accounts = provider.supplyList();
        Test.stopTest();

        // Assert
        Set<Object> labels = new Set<Object>();
        for (SObject generated : accounts) {
            labels.add(generated.get(Account.Description));
        }
        Assert.areEqual(new Set<Object>{ '1 of 3', '2 of 3', '3 of 3' }, labels,
                'each row sees all three sibling primaries and its own rowIndex');
    }

    // In-test expressions and Providers ----------------------

    /** A context-aware expression whose generated value is legitimately null. */
    private class AlwaysNull implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            return null;
        }
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

    /** Reads the whole batch of sibling primary records out of `bundleSoFar`. */
    private class SiblingCountLabel implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            Integer siblingCount = context.bundleSoFar.getList(Account.Id).size();
            return (context.rowIndex + 1) + ' of ' + siblingCount;
        }
    }
}
