/**
 * Proves `XFTY_EnrichmentPaths` - config plus bundle shape to a concrete path
 * set. Pure in-memory bundles, no DML/SOQL.
 */
@IsTest
private class XFTY_EnrichmentPathsTest {

    @IsTest
    static void testParentPaths_fromNothing_isEmpty() {
        // Arrange
        XFTY_DummySObjectBundle sub = twoLevelAncestorBundle();

        // Act
        Test.startTest();
        List<List<SObjectField>> paths = XFTY_EnrichmentPaths.parentPaths(sub, XFTY_InjectConfig.nothing());
        Test.stopTest();

        // Assert
        Assert.areEqual(0, paths.size());
    }

    @IsTest
    static void testParentPaths_fromAllParents_walksTheBundleToEveryLevel() {
        // Arrange
        XFTY_DummySObjectBundle sub = twoLevelAncestorBundle();

        // Act
        Test.startTest();
        List<List<SObjectField>> paths = XFTY_EnrichmentPaths.parentPaths(sub, XFTY_InjectConfig.allParents());
        Test.stopTest();

        // Assert
        Assert.areEqual(2, paths.size(), '[AccountId] and [AccountId, ParentId]');
    }

    @IsTest
    static void testParentPaths_fromAllParents_respectsTheDepthLimit() {
        // Arrange
        XFTY_DummySObjectBundle sub = twoLevelAncestorBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents().parentDepth(1);

        // Act
        Test.startTest();
        List<List<SObjectField>> paths = XFTY_EnrichmentPaths.parentPaths(sub, config);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, paths.size(), 'only the first hop');
    }

    @IsTest
    static void testParentPaths_withInjectParent_addsThePathAndItsPrefixes() {
        // Arrange
        XFTY_DummySObjectBundle sub = new XFTY_DummySObjectBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectParent(
                new List<SObjectField>{ Contact.AccountId, Account.ParentId }
        );

        // Act
        Test.startTest();
        List<List<SObjectField>> paths = XFTY_EnrichmentPaths.parentPaths(sub, config);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, paths.size(), 'the path plus its one prefix');
    }

    @IsTest
    static void testParentPaths_withExcludeParent_dropsThatSubtree() {
        // Arrange
        XFTY_DummySObjectBundle sub = twoLevelAncestorBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents()
                .excludeParent(new List<SObjectField>{ Contact.AccountId });

        // Act
        Test.startTest();
        List<List<SObjectField>> paths = XFTY_EnrichmentPaths.parentPaths(sub, config);
        Test.stopTest();

        // Assert
        Assert.areEqual(0, paths.size(), 'excluding the head prunes the whole chain');
    }

    @IsTest
    static void testChildFields_fromAllChildren_returnsTheBundlesChildFields() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Account.Id, new List<SObject>{ new Account() });
        bundle.putChild(Contact.AccountId, new XFTY_DummySObjectBundle(), new List<Integer>());

        // Act
        Test.startTest();
        Set<SObjectField> fields = XFTY_EnrichmentPaths.childFields(bundle, XFTY_InjectConfig.allChildren());
        Test.stopTest();

        // Assert
        Assert.isTrue(fields.contains(Contact.AccountId));
    }

    @IsTest
    static void testLongestFirst_ordersByPathLengthDescending() {
        // Arrange
        List<List<SObjectField>> paths = new List<List<SObjectField>>{
                new List<SObjectField>{ Contact.AccountId },
                new List<SObjectField>{ Contact.AccountId, Account.ParentId }
        };

        // Act
        Test.startTest();
        List<List<SObjectField>> ordered = XFTY_EnrichmentPaths.longestFirst(paths);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, ordered[0].size(), 'the longer path is first');
    }

    @IsTest
    static void testKeyOf_isStableAndPositionalForAPath() {
        // Arrange
        List<SObjectField> path = new List<SObjectField>{ Contact.AccountId, Account.ParentId };

        // Act
        Test.startTest();
        String key = XFTY_EnrichmentPaths.keyOf(path);
        Test.stopTest();

        // Assert
        Assert.areEqual('AccountId>ParentId>', key);
    }

    static XFTY_DummySObjectBundle twoLevelAncestorBundle() {
        XFTY_DummySObjectBundle accountBundle = new XFTY_DummySObjectBundle();
        accountBundle.put(Account.ParentId, new List<SObject>{ new Account() });
        accountBundle.put(Account.ParentId, new XFTY_DummySObjectBundle());
        XFTY_DummySObjectBundle sub = new XFTY_DummySObjectBundle();
        sub.put(Contact.AccountId, new List<SObject>{ new Account() });
        sub.put(Contact.AccountId, accountBundle);
        return sub;
    }
}
