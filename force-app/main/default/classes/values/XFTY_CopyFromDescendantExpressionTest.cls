/**
 * `XFTY_CopyFromDescendantExpression` - a parent field copied up from a generated child,
 * resolved in the `DEFERRED` flush once the whole forest exists.
 *
 * See docs/roadmap/descendant-value-reads.md.
 */
@IsTest
private class XFTY_CopyFromDescendantExpressionExpressionTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final String CHILD_DEPARTMENT = 'Field Ops';

    @IsTest
    static void aGeneratedAncestorReadsAValueUpFromItsChild() {
        // Arrange - a Contact that pulls in an Account whose Site copies the Contact's Department
        XFTY_DummySObjectProviderLookupIntf lookup = accountReadingChildDepartment();

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            supplyContactDeferred(lookup);
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Contact child = [SELECT Department FROM Contact LIMIT 1];
        Account parent = [SELECT Site FROM Account LIMIT 1];
        Assert.areEqual(CHILD_DEPARTMENT, child.Department, 'sanity: the child carries the value');
        Assert.areEqual(child.Department, parent.Site, 'the ancestor copied the value up from its child');
    }

    @IsTest
    static void aParentReadsUpFromOneOfItsWithChildrenRows() {
        // Arrange - an Account with three child Contacts; Site copies the first child's Department
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountReadingChildDepartment()
                }
        );

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .with(new XFTY_SObjectChildProvider(Contact.AccountId)
                            .setQuantity(3)
                            .put(Contact.Department, CHILD_DEPARTMENT))
                    .supply();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(3, [SELECT COUNT() FROM Contact]);
        Account parent = [SELECT Site FROM Account];
        Assert.areEqual(CHILD_DEPARTMENT, parent.Site, 'the parent copied its first child collection row up');
    }

    @IsTest
    static void noMatchingChildLeavesTheValueNull() {
        // Arrange - the up-flow field points at a child relationship nothing generates
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new AccountReadingChildDepartment()
                }
        );

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
                    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                    .supply();
            XFTY_DeferredInserter.flush();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(null, [SELECT Site FROM Account].Site, 'no child means null, not an error');
    }

    @IsTest
    static void anUpFlowValueInANonDeferredModeThrowsLoudly() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = accountReadingChildDepartment();

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'an up-flow value outside DEFERRED must throw, not silently null');
        Assert.isTrue(thrown.getMessage().contains('DEFERRED'), thrown.getMessage());
    }

    @IsTest
    static void depthBatchedAlsoResolvesTheUpFlowValue() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = accountReadingChildDepartment();

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .depthBatched()
                    .put(Contact.Department, CHILD_DEPARTMENT)
                    .supply();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(CHILD_DEPARTMENT, [SELECT Site FROM Account].Site,
                '.depthBatched() also has the whole graph before insert');
    }

    @IsTest
    static void constructorRejectsNulls() {
        // Arrange
        // nothing to arrange - the bad construction is the act

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            new XFTY_CopyFromDescendantExpression(null, Contact.Department);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'a null field must be rejected at construction');
        Assert.isTrue(thrown.getMessage().containsIgnoreCase('child lookup field'), thrown.getMessage());
    }

    // Fixture ---------------------------------------------------------------

    private static void supplyContactDeferred(XFTY_DummySObjectProviderLookupIntf lookup) {
        new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .put(Contact.Department, CHILD_DEPARTMENT)
                .supply();
    }

    private static XFTY_DummySObjectProviderLookupIntf accountReadingChildDepartment() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new AccountReadingChildDepartment(),
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactUnderReadingAccount()
        });
    }

    /** An Account whose Site is copied up from the Contact that references it. */
    private class AccountReadingChildDepartment implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_IncrementingStringExpression('Acct'))
                .put(Account.Site, new XFTY_CopyFromDescendantExpression(Contact.AccountId, Contact.Department));

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

    /** A Contact that pulls in the reading Account. */
    private class ContactUnderReadingAccount implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_IncrementingStringExpression('Leaf'))
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));

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
}
