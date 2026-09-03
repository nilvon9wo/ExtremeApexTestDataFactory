/**
 * Proves `XFTY_EnrichmentSelection` - "does this config want the ancestor / child
 * / inverse here?". Pure in-memory, no DML/SOQL.
 */
@IsTest
private class XFTY_EnrichmentSelectionTest {

    @IsTest
    static void testWantsAncestor_fromNothing_isFalse() {
        // Arrange
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(XFTY_InjectConfig.nothing());

        // Act
        Test.startTest();
        Boolean wanted = selection.wantsAncestor(new List<SObjectField>{ Contact.AccountId });
        Test.stopTest();

        // Assert
        Assert.isFalse(wanted);
    }

    @IsTest
    static void testWantsAncestor_fromAllParents_isTrueForAnyUpwardPath() {
        // Arrange
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(XFTY_InjectConfig.allParents());

        // Act
        Test.startTest();
        Boolean wanted = selection.wantsAncestor(new List<SObjectField>{ Contact.AccountId, Account.ParentId });
        Test.stopTest();

        // Assert
        Assert.isTrue(wanted);
    }

    @IsTest
    static void testWantsAncestor_forAnInjectParentLeaf_isTrueForEveryPrefix() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectParent(
                new List<SObjectField>{ Contact.AccountId, Account.ParentId }
        );
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(config);

        // Act
        Test.startTest();
        Boolean prefixWanted = selection.wantsAncestor(new List<SObjectField>{ Contact.AccountId });
        Test.stopTest();

        // Assert
        Assert.isTrue(prefixWanted, 'the hop on the way to the named leaf is wanted');
        Assert.isTrue(selection.wantsAncestor(new List<SObjectField>{ Contact.AccountId, Account.ParentId }));
        Assert.isFalse(selection.wantsAncestor(new List<SObjectField>{ Contact.OwnerId }), 'an unrelated hop is not');
    }

    @IsTest
    static void testWantsAncestor_whenAPrefixIsExcluded_isFalse() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents()
                .excludeParent(new List<SObjectField>{ Contact.AccountId });
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(config);

        // Act
        Test.startTest();
        Boolean wanted = selection.wantsAncestor(new List<SObjectField>{ Contact.AccountId, Account.ParentId });
        Test.stopTest();

        // Assert
        Assert.isFalse(wanted, 'excluding the head prunes the whole chain');
    }

    @IsTest
    static void testWantsAncestor_whenTheWalkHasTurnedDownward_followsOnlyFromAllParents() {
        // Arrange - a null path means "inside a child's ancestors"
        XFTY_EnrichmentSelection namedOnly = new XFTY_EnrichmentSelection(
                XFTY_InjectConfig.nothing().injectParent(new List<SObjectField>{ Contact.AccountId })
        );
        XFTY_EnrichmentSelection breadth = new XFTY_EnrichmentSelection(XFTY_InjectConfig.allParents());

        // Act
        Test.startTest();
        Boolean namedReaches = namedOnly.wantsAncestor(null);
        Test.stopTest();

        // Assert
        Assert.isFalse(namedReaches, 'injectParent does not reach into a child\'s ancestors');
        Assert.isTrue(breadth.wantsAncestor(null), 'allParents does');
    }

    @IsTest
    static void testWantsInverse_needsFromAllChildrenAndNoExclude() {
        // Arrange
        XFTY_EnrichmentSelection all = new XFTY_EnrichmentSelection(XFTY_InjectConfig.allChildren());
        XFTY_EnrichmentSelection excluded = new XFTY_EnrichmentSelection(
                XFTY_InjectConfig.allChildren().excludeChild(Contact.AccountId)
        );

        // Act
        Test.startTest();
        Boolean wanted = all.wantsInverse(Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.isTrue(wanted);
        Assert.isFalse(excluded.wantsInverse(Contact.AccountId));
        Assert.isFalse(new XFTY_EnrichmentSelection(XFTY_InjectConfig.nothing()).wantsInverse(Contact.AccountId));
    }

    @IsTest
    static void testChildFieldsOn_fromAllChildren_returnsThePresentChildFields() {
        // Arrange
        XFTY_DummySObjectBundle bundle = accountBundleWithChildren();
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(XFTY_InjectConfig.allChildren());

        // Act
        Test.startTest();
        Set<SObjectField> fields = selection.childFieldsOn(bundle, true);
        Test.stopTest();

        // Assert
        Assert.isTrue(fields.contains(Contact.AccountId));
    }

    @IsTest
    static void testChildFieldsOn_forAnInjectChildField_appliesOnlyAtTheRoot() {
        // Arrange
        XFTY_DummySObjectBundle bundle = accountBundleWithChildren();
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(
                XFTY_InjectConfig.nothing().injectChild(Contact.AccountId)
        );

        // Act
        Test.startTest();
        Set<SObjectField> atRoot = selection.childFieldsOn(bundle, true);
        Test.stopTest();

        // Assert
        Assert.isTrue(atRoot.contains(Contact.AccountId));
        Assert.isTrue(selection.childFieldsOn(bundle, false).isEmpty(), 'a named child collection is not injected on a nested position');
    }

    @IsTest
    static void testChildFieldsOn_whenExcluded_dropsTheField() {
        // Arrange
        XFTY_DummySObjectBundle bundle = accountBundleWithChildren();
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(
                XFTY_InjectConfig.allChildren().excludeChild(Contact.AccountId)
        );

        // Act
        Test.startTest();
        Set<SObjectField> fields = selection.childFieldsOn(bundle, true);
        Test.stopTest();

        // Assert
        Assert.isFalse(fields.contains(Contact.AccountId));
    }

    @IsTest
    static void testKeyOf_isPositionalAndNullSafe() {
        // Arrange
        List<SObjectField> path = new List<SObjectField>{ Contact.AccountId, Account.ParentId };

        // Act
        Test.startTest();
        String key = XFTY_EnrichmentSelection.keyOf(path);
        Test.stopTest();

        // Assert
        Assert.areEqual('AccountId>ParentId>', key);
        Assert.areEqual('', XFTY_EnrichmentSelection.keyOf(null));
    }

    static XFTY_DummySObjectBundle accountBundleWithChildren() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Account.Id, new List<SObject>{ new Account() });
        bundle.putChild(Contact.AccountId, new XFTY_DummySObjectBundle(), new List<Integer>());
        return bundle;
    }
}
