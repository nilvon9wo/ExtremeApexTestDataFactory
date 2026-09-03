/**
 * Proves `XFTY_InjectConfig` - a plain fluent state carrier for
 * `bundle.inject(field, config)`. No DML/SOQL.
 */
@IsTest
private class XFTY_InjectConfigTest {

    @IsTest
    static void testNothing_startsFromNeitherBreadth() {
        // Arrange
        XFTY_InjectConfig config;

        // Act
        Test.startTest();
        config = XFTY_InjectConfig.nothing();
        Test.stopTest();

        // Assert
        Assert.isFalse(config.fromAllParents);
        Assert.isFalse(config.fromAllChildren);
    }

    @IsTest
    static void testAllParents_startsFromParentsOnly() {
        // Arrange
        XFTY_InjectConfig config;

        // Act
        Test.startTest();
        config = XFTY_InjectConfig.allParents();
        Test.stopTest();

        // Assert
        Assert.isTrue(config.fromAllParents);
        Assert.isFalse(config.fromAllChildren);
    }

    @IsTest
    static void testAllChildren_startsFromChildrenOnly() {
        // Arrange
        XFTY_InjectConfig config;

        // Act
        Test.startTest();
        config = XFTY_InjectConfig.allChildren();
        Test.stopTest();

        // Assert
        Assert.isFalse(config.fromAllParents);
        Assert.isTrue(config.fromAllChildren);
    }

    @IsTest
    static void testEverything_startsFromBothBreadths() {
        // Arrange
        XFTY_InjectConfig config;

        // Act
        Test.startTest();
        config = XFTY_InjectConfig.everything();
        Test.stopTest();

        // Assert
        Assert.isTrue(config.fromAllParents);
        Assert.isTrue(config.fromAllChildren);
    }

    @IsTest
    static void testDefaults_areTheSoqlLimits() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing();

        // Act
        Test.startTest();
        Integer parent = config.parentDepthLimit;
        Test.stopTest();

        // Assert
        Assert.areEqual(XFTY_InjectConfig.SOQL_PARENT_HOPS, parent);
        Assert.areEqual(XFTY_InjectConfig.SOQL_CHILD_DEPTH, config.childDepthLimit);
        Assert.isFalse(config.soqlLimitsLifted);
    }

    @IsTest
    static void testInjectParent_addsThePathAndReturnsTheConfig() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing();
        List<SObjectField> path = new List<SObjectField>{ Contact.AccountId, Account.ParentId };

        // Act
        Test.startTest();
        XFTY_InjectConfig returned = config.injectParent(path);
        Test.stopTest();

        // Assert
        Assert.areEqual(config, returned, 'fluent');
        Assert.areEqual(path, config.includedParentPaths[0]);
    }

    @IsTest
    static void testInjectChild_addsTheChildField() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing();

        // Act
        Test.startTest();
        config.injectChild(Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.isTrue(config.includedChildFields.contains(Contact.AccountId));
    }

    @IsTest
    static void testExcludeParent_addsThePath() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.everything();
        List<SObjectField> path = new List<SObjectField>{ Case.OwnerId };

        // Act
        Test.startTest();
        config.excludeParent(path);
        Test.stopTest();

        // Assert
        Assert.areEqual(path, config.excludedParentPaths[0]);
    }

    @IsTest
    static void testExcludeChild_addsTheChildField() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.everything();

        // Act
        Test.startTest();
        config.excludeChild(Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.isTrue(config.excludedChildFields.contains(Contact.AccountId));
    }

    @IsTest
    static void testInjectValue_withAFieldAndValue_recordsItAgainstTheField() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing();

        // Act
        Test.startTest();
        config.injectValue(Account.AnnualRevenue, 5000);
        Test.stopTest();

        // Assert
        Assert.areEqual(5000, config.onRecordValues.get(Account.AnnualRevenue));
    }

    @IsTest
    static void testInjectValue_withAPathAndValue_addsAnAncestorValue() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing();
        List<SObjectField> pathToField = new List<SObjectField>{ Contact.AccountId, Account.Name };

        // Act
        Test.startTest();
        config.injectValue(pathToField, 'Forced');
        Test.stopTest();

        // Assert
        Assert.areEqual('Forced', config.ancestorValues[0].value);
        Assert.areEqual(Account.Name, config.ancestorValues[0].targetField());
    }

    @IsTest
    static void testInjectChildValue_withTwoFields_addsAChildValueOnTheOneHopPath() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing();

        // Act
        Test.startTest();
        config.injectChildValue(Contact.AccountId, Contact.Description, 'note');
        Test.stopTest();

        // Assert
        Assert.areEqual('note', config.childValues[0].value);
        Assert.areEqual(Contact.Description, config.childValues[0].targetField());
        Assert.areEqual(
                new List<SObjectField>{ Contact.AccountId },
                config.childValues[0].relationshipPrefix()
        );
    }

    @IsTest
    static void testInjectChildValue_withAPath_keepsEveryHop() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing();
        List<SObjectField> path = new List<SObjectField>{ Contact.AccountId, Case.ContactId, Case.Subject };

        // Act
        Test.startTest();
        config.injectChildValue(path, 'x');
        Test.stopTest();

        // Assert
        Assert.areEqual(path, config.childValues[0].path);
        Assert.areEqual(Case.Subject, config.childValues[0].targetField());
    }

    @IsTest
    static void testParentDepth_overridesTheLimit() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents();

        // Act
        Test.startTest();
        config.parentDepth(2);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, config.parentDepthLimit);
    }

    @IsTest
    static void testChildDepth_overridesTheLimit() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.allChildren();

        // Act
        Test.startTest();
        config.childDepth(3);
        Test.stopTest();

        // Assert
        Assert.areEqual(3, config.childDepthLimit);
    }

    @IsTest
    static void testBreakSoqlLimits_liftsTheFlag() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.everything();

        // Act
        Test.startTest();
        config.breakSoqlLimits();
        Test.stopTest();

        // Assert
        Assert.isTrue(config.soqlLimitsLifted);
    }
}
