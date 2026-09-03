/**
 * Proves `XFTY_EnrichmentSelection` - "does this config want the ancestor / child
 * / inverse here?". Pure in-memory, no DML/SOQL. Parameterised: the `@IsTest`
 * methods are data rows; the runners hold the AAA.
 */
@IsTest
private class XFTY_EnrichmentSelectionTest {

    static List<SObjectField> account() {
        return new List<SObjectField>{ Contact.AccountId };
    }

    static List<SObjectField> accountParent() {
        return new List<SObjectField>{ Contact.AccountId, Account.ParentId };
    }

    static List<SObjectField> owner() {
        return new List<SObjectField>{ Contact.OwnerId };
    }

    @IsTest
    static void testWantsAncestor_fromNothing_isFalse() {
        testWantsAncestor(XFTY_InjectConfig.nothing(), account(), false);
    }

    @IsTest
    static void testWantsAncestor_fromAllParents_isTrueForAnyUpwardPath() {
        testWantsAncestor(XFTY_InjectConfig.allParents(), accountParent(), true);
    }

    @IsTest
    static void testWantsAncestor_fromAllParentsWhenTheWalkHasTurnedDownward_isTrue() {
        testWantsAncestor(XFTY_InjectConfig.allParents(), null, true);
    }

    @IsTest
    static void testWantsAncestor_fromNothingWhenTheWalkHasTurnedDownward_isFalse() {
        testWantsAncestor(XFTY_InjectConfig.nothing().injectParent(account()), null, false);
    }

    @IsTest
    static void testWantsAncestor_forAPrefixOfAnInjectParentLeaf_isTrue() {
        testWantsAncestor(XFTY_InjectConfig.nothing().injectParent(accountParent()), account(), true);
    }

    @IsTest
    static void testWantsAncestor_forAnInjectParentLeafItself_isTrue() {
        testWantsAncestor(XFTY_InjectConfig.nothing().injectParent(accountParent()), accountParent(), true);
    }

    @IsTest
    static void testWantsAncestor_forAnUnrelatedHop_isFalse() {
        testWantsAncestor(XFTY_InjectConfig.nothing().injectParent(accountParent()), owner(), false);
    }

    @IsTest
    static void testWantsAncestor_whenAPrefixIsExcluded_isFalse() {
        testWantsAncestor(XFTY_InjectConfig.allParents().excludeParent(account()), accountParent(), false);
    }

    static void testWantsAncestor(XFTY_InjectConfig config, List<SObjectField> pathFromEntry, Boolean expected) {
        // Arrange
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(config);

        // Act
        Test.startTest();
        Boolean wanted = selection.wantsAncestor(pathFromEntry);
        Test.stopTest();

        // Assert
        Assert.areEqual(expected, wanted);
    }

    @IsTest
    static void testWantsInverse_fromAllChildren_isTrue() {
        testWantsInverse(XFTY_InjectConfig.allChildren(), true);
    }

    @IsTest
    static void testWantsInverse_fromNothing_isFalse() {
        testWantsInverse(XFTY_InjectConfig.nothing(), false);
    }

    @IsTest
    static void testWantsInverse_whenTheRelationshipIsExcluded_isFalse() {
        testWantsInverse(XFTY_InjectConfig.allChildren().excludeChild(Contact.AccountId), false);
    }

    static void testWantsInverse(XFTY_InjectConfig config, Boolean expected) {
        // Arrange
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(config);

        // Act
        Test.startTest();
        Boolean wanted = selection.wantsInverse(Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(expected, wanted);
    }

    static List<SObjectField> rootPath() {
        return new List<SObjectField>();
    }

    static List<SObjectField> oneChildHop() {
        return new List<SObjectField>{ Contact.AccountId };
    }

    @IsTest
    static void testChildFieldsOn_fromAllChildren_includesThePresentField() {
        testChildFieldsOnContains(XFTY_InjectConfig.allChildren(), rootPath(), true);
    }

    @IsTest
    static void testChildFieldsOn_whenExcluded_dropsTheField() {
        testChildFieldsOnContains(XFTY_InjectConfig.allChildren().excludeChild(Contact.AccountId), rootPath(), false);
    }

    @IsTest
    static void testChildFieldsOn_forAnInjectChildFieldAtTheRoot_includesIt() {
        testChildFieldsOnContains(XFTY_InjectConfig.nothing().injectChild(Contact.AccountId), rootPath(), true);
    }

    @IsTest
    static void testChildFieldsOn_forAnInjectChildFieldNotAtTheRoot_excludesIt() {
        testChildFieldsOnContains(XFTY_InjectConfig.nothing().injectChild(Contact.AccountId), oneChildHop(), false);
    }

    @IsTest
    static void testChildFieldsOn_forAnInjectChildValuePathAtTheRoot_includesItsFirstHop() {
        testChildFieldsOnContains(
                XFTY_InjectConfig.nothing().injectChildValue(Contact.AccountId, Contact.Description, 'x'),
                rootPath(),
                true
        );
    }

    static void testChildFieldsOnContains(
            XFTY_InjectConfig config,
            List<SObjectField> childPathHere,
            Boolean expectedToContain
    ) {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Account.Id, new List<SObject>{ new Account() });
        bundle.putChild(Contact.AccountId, new XFTY_DummySObjectBundle(), new List<Integer>());
        XFTY_EnrichmentSelection selection = new XFTY_EnrichmentSelection(config);

        // Act
        Test.startTest();
        Set<SObjectField> fields = selection.childFieldsOn(bundle, childPathHere);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedToContain, fields.contains(Contact.AccountId));
    }

}
