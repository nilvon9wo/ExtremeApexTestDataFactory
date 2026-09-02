/**
 * Proves `XFTY_DummySObjectMasterTemplate` - the declarative description of how
 * one SObject type is generated. Pure in-memory map manipulation, no DML/SOQL.
 */
@IsTest
private class XFTY_DummySObjectMasterTemplateTest {

    // Constructor ---------------------------------------------------

    @IsTest
    static void testConstructor_seedsEmptyMapsAndKeepsThePrimaryTargetField() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id);
        Test.stopTest();

        // Assert
        Assert.areEqual(Account.Id, template.primaryTargetField);
        Assert.areEqual(0, template.defaultBySObjectFieldMap.size());
        Assert.areEqual(0, template.requiredRelationshipBySObjectFieldMap.size());
        Assert.areEqual(0, template.optionalRelationshipBySObjectFieldMap.size());
    }

    // put(field, valueExpression) --------------------------------

    @IsTest
    static void testPut_forAPlainValueExpression_routesItToTheDefaultMap() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_LiteralExpression('Doe'));
        Test.stopTest();

        // Assert
        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Contact.LastName));
    }

    @IsTest
    static void testPut_forATypedContextAwareExpression_routesItToTheContextAwareMap() {
        testContextAwarePutRouting(false);
    }

    @IsTest
    static void testPut_forAContextAwareExpressionPassedAsObject_routesItToTheContextAwareMap() {
        testContextAwarePutRouting(true);
    }

    @IsTest
    static void testPut_whenReplacingAPlainFieldWithAContextAwareExpression_movesItBetweenMaps() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_LiteralExpression('plain'))
                .put(Account.Name, new XFTY_CopyFromSiblingExpression(Account.AccountNumber));
        Test.stopTest();

        // Assert
        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Account.Name), 'left the plain-value map');
        Assert.isTrue(template.contextAwareBySObjectFieldMap.containsKey(Account.Name), 'landed in the context-aware map');
    }

    @IsTest
    static void testPut_forABareLiteral_wrapsItAsAnExactValue() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Type, 'Customer');
        Test.stopTest();

        // Assert
        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Account.Type));
        Assert.areEqual('Customer', template.defaultBySObjectFieldMap.get(Account.Type).get());
    }

    @IsTest
    static void testPut_forAnExistingExpressionPassedAsObject_doesNotDoubleWrapIt() {
        // Arrange
        XFTY_ValueExpressionIntf expression = new XFTY_IncrementingStringExpression('Acct');

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, (Object) expression);
        Test.stopTest();

        // Assert
        Assert.areEqual(expression, template.defaultBySObjectFieldMap.get(Account.Name));
    }

    @IsTest
    static void testPut_whenGivenARelationshipAsObject_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.AccountId, (Object) new XFTY_DummyDefaultRelationship(new Account()));
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('putRequired'), thrown.getMessage());
    }

    // putRequired / putOptional --------------------------------

    @IsTest
    static void testPutRequired_routesTheRelationshipToTheRequiredMap() {
        // Arrange
        XFTY_DummyDefaultRelationship required = new XFTY_DummyDefaultRelationship(new Account());

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .putRequired(Contact.AccountId, required);
        Test.stopTest();

        // Assert
        Assert.areEqual(required, template.requiredRelationshipBySObjectFieldMap.get(Contact.AccountId));
        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Contact.AccountId));
    }

    @IsTest
    static void testPutOptional_routesTheRelationshipToTheOptionalMap() {
        // Arrange
        XFTY_DummyDefaultRelationship optional = new XFTY_DummyDefaultRelationship(new Contact());

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .putOptional(Contact.ReportsToId, optional);
        Test.stopTest();

        // Assert
        Assert.areEqual(optional, template.optionalRelationshipBySObjectFieldMap.get(Contact.ReportsToId));
    }

    // remove(field) -------------------------------------------

    @IsTest
    static void testRemove_clearsTheFieldFromEveryMapAndFromTheOrderedFields() {
        // Arrange
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_LiteralExpression('Doe'))
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));

        // Act
        Test.startTest();
        template.remove(Contact.LastName);
        template.remove(Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Contact.LastName));
        Assert.isFalse(template.requiredRelationshipBySObjectFieldMap.containsKey(Contact.AccountId));
        Assert.isFalse(new Set<SObjectField>(template.orderedValueFields()).contains(Contact.LastName));
    }

    // orderedValueFields() -----------------------------------

    @IsTest
    static void testOrderedValueFields_followsPutOrder() {
        // Arrange
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_LiteralExpression('n'))
                .put(Account.Industry, new XFTY_LiteralExpression('i'))
                .put(Account.Type, new XFTY_LiteralExpression('t'));

        // Act
        Test.startTest();
        List<SObjectField> ordered = template.orderedValueFields();
        Test.stopTest();

        // Assert
        Assert.areEqual(new List<SObjectField>{ Account.Name, Account.Industry, Account.Type }, ordered);
    }

    @IsTest
    static void testOrderedValueFields_afterRemoveThenRePut_keepsTheFieldInItsOriginalPlace() {
        // Arrange
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_LiteralExpression('n'))
                .put(Account.Industry, new XFTY_LiteralExpression('i'))
                .put(Account.Type, new XFTY_LiteralExpression('t'));
        template.remove(Account.Industry);

        // Act
        Test.startTest();
        template.put(Account.Name, new XFTY_LiteralExpression('n2'));
        Test.stopTest();

        // Assert
        Assert.areEqual(new List<SObjectField>{ Account.Name, Account.Type }, template.orderedValueFields());
    }

    // copy() -------------------------------------------------

    @IsTest
    static void testCopy_reflectsItsOwnEdits() {
        // Arrange
        XFTY_DummySObjectMasterTemplate original = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_LiteralExpression('Original'));

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate copy = original.copy();
        Test.stopTest();
        copy.put(Account.Industry, new XFTY_LiteralExpression('Tech'));
        copy.remove(Account.Name);

        // Assert
        Assert.isTrue(copy.defaultBySObjectFieldMap.containsKey(Account.Industry));
        Assert.isFalse(copy.defaultBySObjectFieldMap.containsKey(Account.Name));
        Assert.areEqual(Account.Id, copy.primaryTargetField);
    }

    @IsTest
    static void testCopy_leavesTheOriginalUntouchedWhenTheCopyIsEdited() {
        // Arrange
        XFTY_DummySObjectMasterTemplate original = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_LiteralExpression('Original'));

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate copy = original.copy();
        Test.stopTest();
        copy.put(Account.Industry, new XFTY_LiteralExpression('Tech'));
        copy.remove(Account.Name);

        // Assert
        Assert.isFalse(original.defaultBySObjectFieldMap.containsKey(Account.Industry));
        Assert.isTrue(original.defaultBySObjectFieldMap.containsKey(Account.Name));
    }

    @IsTest
    static void testCopy_carriesAContextAwareEntry() {
        // Arrange
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_CopyFromSiblingExpression(Account.AccountNumber));

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate copy = template.copy();
        Test.stopTest();

        // Assert
        Assert.isTrue(copy.contextAwareBySObjectFieldMap.containsKey(Account.Name));
    }

    // Runner -----------------------------------------------

    static void testContextAwarePutRouting(Boolean passAsObject) {
        // Arrange
        XFTY_ContextAwareExpressionIntf contextAware = new XFTY_CopyFromSiblingExpression(Contact.FirstName);
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id);

        // Act
        Test.startTest();
        if (passAsObject) {
            template.put(Contact.LastName, (Object) contextAware);
        } else {
            template.put(Contact.LastName, contextAware);
        }
        Test.stopTest();

        // Assert
        Assert.areEqual(contextAware, template.contextAwareBySObjectFieldMap.get(Contact.LastName));
        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Contact.LastName), 'not in the plain-value map');
        Assert.isTrue(new Set<SObjectField>(template.orderedValueFields()).contains(Contact.LastName),
                'still in the ordered value fields');
    }
}
