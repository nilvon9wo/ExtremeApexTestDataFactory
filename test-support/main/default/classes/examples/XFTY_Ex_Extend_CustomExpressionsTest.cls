/**
 * Runnable proof for docs/extend/custom-value-expressions.md - implementing each
 * of the three value interfaces, and the limits documented for each.
 *
 * Every `@IsTest` method is one example or one stated limitation from that page.
 */
@IsTest
private class XFTY_Ex_Extend_CustomExpressionsTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // --- Plain: XFTY_ValueExpressionIntf --------------------------------

    @IsTest
    static void testGet_forAPlainValueExpression_seesNothingButItself() {
        // Arrange
        // nothing to arrange

        // Act
        Task result;
        Test.startTest();
        result = (Task) new XFTY_DummySObjectProvider(Task.SObjectType, taskLookup())
                .put(Task.ActivityDate, new NextWeekday())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.ActivityDate);
        Date startOfWeek = result.ActivityDate.toStartOfWeek();
        Assert.isTrue(result.ActivityDate != startOfWeek && result.ActivityDate != startOfWeek.addDays(6),
                'not a weekend: ' + result.ActivityDate);
    }

    // --- Sibling: XFTY_ContextAwareExpressionIntf ----------------------------

    @IsTest
    static void testGet_forAContextAwareExpression_readsASiblingFieldAsAValue() {
        // Arrange
        // nothing to arrange - MailingCountry is generated first, Description derives from it

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.MailingCountry, 'Germany')
                .put(Contact.Description, new SiblingCountryLabel())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Billing: Germany', result.Description);
    }

    // --- Ancestor: XFTY_ContextAwareExpressionIntf, non-Id field -------------

    @IsTest
    static void testGet_forAnAncestorNonIdFieldRead_isReliableInEveryMode() {
        // Arrange - the Contact's Description copies its generated Account's ShippingCountry
        Map<XFTY_InsertModeEnum, String> countryByMode = new Map<XFTY_InsertModeEnum, String>();

        // Act - one supply per insert mode
        Test.startTest();
        for (XFTY_InsertModeEnum mode : new List<XFTY_InsertModeEnum>{
                XFTY_InsertModeEnum.NEVER, XFTY_InsertModeEnum.MOCK
        }) {
            Contact generated = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .put(Contact.Description, new AncestorAccountCountry())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(mode)
                    .supply();
            countryByMode.put(mode, generated.Description);
        }
        Test.stopTest();

        // Assert - the non-Id ancestor field is filled regardless of mode
        Assert.areEqual(
                XFTY_DefaultAccountDataProvider.DEFAULT_SHIPPING_COUNTRY,
                countryByMode.get(XFTY_InsertModeEnum.NEVER)
        );
        Assert.areEqual(
                XFTY_DefaultAccountDataProvider.DEFAULT_SHIPPING_COUNTRY,
                countryByMode.get(XFTY_InsertModeEnum.MOCK)
        );
    }

    // --- Ancestor: XFTY_ContextAwareExpressionIntf, the ancestor's Id --------

    @IsTest
    static void testGet_forAnAncestorIdRead_isOnlyRealUnderNow() {
        // Arrange - the Contact's Description copies its generated Account's Id (as a string)

        // Act
        String underNever;
        String underMock;
        String underNow;
        Test.startTest();
        underNever = descriptionFromAncestorId(XFTY_InsertModeEnum.NEVER);
        underMock = descriptionFromAncestorId(XFTY_InsertModeEnum.MOCK);
        System.runAs(TEST_ADMIN) {
            underNow = descriptionFromAncestorId(XFTY_InsertModeEnum.NOW);
        }
        Test.stopTest();

        // Assert - the strategy runs before insert, so only NOW has a real Id by then
        Assert.areEqual(null, underNever, 'NEVER: the ancestor has no Id when the strategy runs');
        Assert.isNotNull(underMock, 'MOCK: a consistent mock Id');
        Assert.isTrue(underMock.startsWith('001'), underMock);
        Assert.isNotNull(underNow, 'NOW: the ancestor is already inserted, so a real Id');
        Assert.isTrue(underNow.startsWith('001'), underNow);
    }

    @IsTest
    static void testGet_forAnAncestorIdReadUnderDeferred_isNullAtExpressionTimeEvenAfterFlush() {
        // Arrange - DEFERRED: the ancestor has no Id until flush(), which is after the strategy
        Contact generated;
        System.runAs(TEST_ADMIN) {
            generated = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .put(Contact.Description, new AncestorAccountIdAsText())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supply();

            // Act
            Test.startTest();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert - the AccountId lookup IS wired by the depth-batched insert...
        Assert.isNotNull(generated.AccountId, 'the lookup field is wired at flush');
        // ...but the context-aware Description ran earlier, with no Id to read
        Assert.areEqual(null, generated.Description,
                'an ancestor-Id context-aware read cannot work under DEFERRED - the strategy runs before flush');
    }

    // --- Descendant: XFTY_DeferredExpressionIntf -----------------------------

    @IsTest
    static void testGet_forADeferredExpression_readsUpFromTheChildrenDeferredBuilds() {
        // Arrange - one Account with two Cases, one still open
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountFlaggingOpenChildCases(),
                        XFTY_LookupKey.get(Case.SObjectType) => new CaseProvider()
                }
        );

        // Act
        Account generated;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .with(new XFTY_SObjectChildProvider(Case.AccountId).setQuantity(1).put(Case.Status, 'Closed'))
                    .with(new XFTY_SObjectChildProvider(Case.AccountId).setQuantity(1).put(Case.Status, 'New'))
                    .supply();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }
        generated = [SELECT Description FROM Account];

        // Assert
        Assert.areEqual('true', generated.Description, 'HasAnyOpenChildCase saw the still-open Case');
    }

    private class AccountFlaggingOpenChildCases implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_IncrementingStringExpression('Descendant Read Acct'))
                .put(Account.Description, new HasAnyOpenChildCase());
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

    /** From the page: an up-flowing value needs its own interface and runs during flush(). */
    private class HasAnyOpenChildCase implements XFTY_DeferredExpressionIntf {
        public Object get(XFTY_DeferredGraph graph, Integer recordIndex) {
            for (SObject child : graph.childrenOf(recordIndex, Case.AccountId)) {
                if (((Case) child).IsClosed == false) {
                    return 'true';
                }
            }
            return 'false';
        }
    }

    private class CaseProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                .put(Case.Subject, new XFTY_IncrementingStringExpression('Descendant Read Case'));
        public SObjectField getPrimaryTargetField() {
            return Case.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }

    // Fixture - strategies from the page --------------------------------

    private static String descriptionFromAncestorId(XFTY_InsertModeEnum mode) {
        Contact generated = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.Description, new AncestorAccountIdAsText())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(mode)
                .supply();
        return generated.Description;
    }

    private static XFTY_DummySObjectProviderLookupIntf taskLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Task.SObjectType) => new BareTaskProvider()
        });
    }

    private class NextWeekday implements XFTY_ValueExpressionIntf {
        public Object get() {
            Date candidate = Date.today().addDays(1);
            while (isWeekend(candidate)) {
                candidate = candidate.addDays(1);
            }
            return candidate;
        }
        private Boolean isWeekend(Date day) {
            Date startOfWeek = day.toStartOfWeek();
            return day == startOfWeek || day == startOfWeek.addDays(6);
        }
    }

    private class SiblingCountryLabel implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            return 'Billing: ' + (String) context.siblingValue(Contact.MailingCountry);
        }
    }

    private class AncestorAccountCountry implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            Account parentAccount = ancestorAccount(context);
            return (parentAccount == null) ? null : parentAccount.ShippingCountry;
        }
    }

    private class AncestorAccountIdAsText implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            Account parentAccount = ancestorAccount(context);
            return (parentAccount == null || parentAccount.Id == null) ? null : String.valueOf(parentAccount.Id);
        }
    }

    private static Account ancestorAccount(XFTY_GenerationContext context) {
        if (context.bundleSoFar == null || context.rowIndex < 0) {
            return null;
        }
        // getList(relationshipField) is the parent for each primary, aligned 1:1
        List<SObject> accounts = context.bundleSoFar.getList(Contact.AccountId);
        return (accounts == null || context.rowIndex >= accounts.size())
                ? null
                : (Account) accounts[context.rowIndex];
    }

    private class BareTaskProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Task.Id)
                .put(Task.Subject, new XFTY_IncrementingStringExpression('Task'));
        public SObjectField getPrimaryTargetField() {
            return Task.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }
}
