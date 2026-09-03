/**
 * Proves `XFTY_QueryableShapeValidator` - the SOQL-shape rail on an
 * `XFTY_InjectConfig`. No DML/SOQL.
 */
@IsTest
private class XFTY_QueryableShapeValidatorTest {

    @IsTest
    static void testValidate_whenTheConfigStaysWithinTheSoqlLimits_passes() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.everything().parentDepth(5).childDepth(1);

        // Act
        Test.startTest();
        XFTY_QueryableShapeValidator.validate(config);
        Test.stopTest();

        // Assert
        Assert.isTrue(true, 'no throw');
    }

    @IsTest
    static void testValidate_whenParentDepthExceedsTheSoqlLimit_throws() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents().parentDepth(6);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_QueryableShapeValidator.validate(config);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('breakSoqlLimits'));
    }

    @IsTest
    static void testValidate_whenChildDepthExceedsOneWithoutBreakSoqlLimits_throws() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.allChildren().childDepth(2);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_QueryableShapeValidator.validate(config);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('breakSoqlLimits'), 'the message points at the escape hatch');
    }

    @IsTest
    static void testValidate_whenChildDepthExceedsOneWithBreakSoqlLimits_passes() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.allChildren().childDepth(3).breakSoqlLimits();

        // Act
        Test.startTest();
        XFTY_QueryableShapeValidator.validate(config);
        Test.stopTest();

        // Assert
        Assert.isTrue(true, 'nested subqueries are allowed once the ceiling is lifted');
    }

    @IsTest
    static void testValidate_whenAnInjectParentPathIsLongerThanTheSoqlLimit_throws() {
        // Arrange
        List<SObjectField> sixHops = new List<SObjectField>{
                Account.ParentId, Account.ParentId, Account.ParentId,
                Account.ParentId, Account.ParentId, Account.ParentId
        };
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectParent(sixHops);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_QueryableShapeValidator.validate(config);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
    }

    @IsTest
    static void testValidate_whenAnInjectChildValuePathIsDeeperThanChildDepth_throws() {
        // Arrange - a 2-child-hop path, but childDepth is still the default 1
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectChildValue(
                new List<SObjectField>{ Contact.AccountId, Case.ContactId, Case.Subject }, 'x'
        );

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_QueryableShapeValidator.validate(config);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('childDepth'), 'the message points at childDepth');
    }

    @IsTest
    static void testValidate_whenAnInjectChildValuePathFitsWithinChildDepth_passes() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .childDepth(2)
                .breakSoqlLimits()
                .injectChildValue(
                        new List<SObjectField>{ Contact.AccountId, Case.ContactId, Case.Subject }, 'x'
                );

        // Act
        Test.startTest();
        XFTY_QueryableShapeValidator.validate(config);
        Test.stopTest();

        // Assert
        Assert.isTrue(true, 'the path fits once childDepth allows two child levels');
    }

    @IsTest
    static void testValidate_whenBreakSoqlLimitsIsSet_allowsAnOverDeepConfig() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents().parentDepth(20).breakSoqlLimits();

        // Act
        Test.startTest();
        XFTY_QueryableShapeValidator.validate(config);
        Test.stopTest();

        // Assert
        Assert.isTrue(true, 'no throw once the ceiling is lifted');
    }
}
