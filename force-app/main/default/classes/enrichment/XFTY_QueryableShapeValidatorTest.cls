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
    static void testValidate_whenChildDepthIsAboveOne_throwsAsUnsupported() {
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
        Assert.isTrue(thrown.getMessage().contains('one level'), 'the message explains child injection is one level');
    }

    @IsTest
    static void testValidate_whenChildDepthIsAboveOneEvenWithBreakSoqlLimits_stillThrows() {
        // Arrange - childDepth is a capability limit, not a SOQL-shape one
        XFTY_InjectConfig config = XFTY_InjectConfig.allChildren().childDepth(3).breakSoqlLimits();

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
    static void testValidate_whenAnInjectChildPathHasMoreThanOneHop_throws() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectChild(
                new List<SObjectField>{ Contact.AccountId, Case.AccountId }
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
        Assert.isTrue(thrown.getMessage().contains('single child-lookup field'));
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
