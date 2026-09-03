/**
 * Proves `XFTY_PathTargetValue` - the value half of an `XFTY_PathValue`, one of
 * five kinds. `applyTo` lands on a master template (in-memory); no DML/SOQL.
 */
@IsTest
private class XFTY_PathTargetValueTest {

    @IsTest
    static void testOfLiteral_isNotARelationshipAndAppliesTheLiteral() {
        // Arrange
        XFTY_PathTargetValue value = XFTY_PathTargetValue.ofLiteral('Acme');
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id);

        // Act
        Test.startTest();
        value.applyTo(template, Account.Name);
        Test.stopTest();

        // Assert
        Assert.isFalse(value.isRelationship());
        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Account.Name));
    }

    @IsTest
    static void testOfExpression_appliesTheExpression() {
        // Arrange
        XFTY_PathTargetValue value = XFTY_PathTargetValue.ofExpression(new XFTY_LiteralExpression('X'));
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id);

        // Act
        Test.startTest();
        value.applyTo(template, Account.Name);
        Test.stopTest();

        // Assert
        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Account.Name));
    }

    @IsTest
    static void testOfRequiredRelationship_isARelationship() {
        // Arrange
        XFTY_PathTargetValue value = XFTY_PathTargetValue.ofRequiredRelationship(
                new XFTY_DummyDefaultRelationship(new Account())
        );

        // Act
        Test.startTest();
        Boolean isRelationship = value.isRelationship();
        Test.stopTest();

        // Assert
        Assert.isTrue(isRelationship);
        Assert.isFalse(value.isSharedRelationship());
    }

    @IsTest
    static void testOfOptionalRelationship_appliesAsAnOptionalRelationship() {
        // Arrange
        XFTY_PathTargetValue value = XFTY_PathTargetValue.ofOptionalRelationship(
                new XFTY_DummyDefaultRelationship(new Account())
        );
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id);

        // Act
        Test.startTest();
        value.applyTo(template, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.isTrue(template.optionalRelationshipBySObjectFieldMap.containsKey(Contact.AccountId));
    }

    @IsTest
    static void testOfContextAware_appliesAsAContextAwareExpression() {
        // Arrange
        XFTY_PathTargetValue value = XFTY_PathTargetValue.ofContextAware(
                new XFTY_CopyFromSiblingExpression(Account.Name)
        );
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id);

        // Act
        Test.startTest();
        value.applyTo(template, Account.Site);
        Test.stopTest();

        // Assert
        Assert.isTrue(template.contextAwareBySObjectFieldMap.containsKey(Account.Site));
    }



}
