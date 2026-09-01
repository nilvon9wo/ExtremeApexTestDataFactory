/**
 * Coverage for `XFTY_DummySObjectMasterTemplate`, the declarative description of
 * how one SObject type should be generated.
 */
@IsTest
private class XFTY_DummySObjectMasterTemplateTest {

    @IsTest
    static void constructorSeedsEmptyMaps() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id);

        Assert.areEqual(Account.Id, template.primaryTargetField);
        Assert.areEqual(0, template.defaultBySObjectFieldMap.size());
        Assert.areEqual(0, template.requiredRelationshipBySObjectFieldMap.size());
        Assert.areEqual(0, template.optionalRelationshipBySObjectFieldMap.size());
    }

    @IsTest
    static void putRoutesEachStrategyTypeToItsOwnMap() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_LiteralExpression('Doe'))
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
                .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()));

        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Contact.LastName));
        Assert.isTrue(template.requiredRelationshipBySObjectFieldMap.containsKey(Contact.AccountId));
        Assert.isTrue(template.optionalRelationshipBySObjectFieldMap.containsKey(Contact.ReportsToId));
    }

    @IsTest
    static void putRoutesAContextAwareStrategyToItsOwnSlot() {
        XFTY_ContextAwareExpressionIntf contextAware = new XFTY_CopyFromSiblingExpression(Contact.FirstName);

        XFTY_DummySObjectMasterTemplate typed = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, contextAware);
        XFTY_DummySObjectMasterTemplate untyped = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, (Object) contextAware);

        for (XFTY_DummySObjectMasterTemplate template : new List<XFTY_DummySObjectMasterTemplate>{ typed, untyped }) {
            Assert.areEqual(contextAware, template.contextAwareBySObjectFieldMap.get(Contact.LastName));
            Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Contact.LastName),
                    'not in the plain-value map');
            Assert.isTrue(new Set<SObjectField>(template.orderedValueFields()).contains(Contact.LastName),
                    'still in the ordered value fields');
        }
    }

    @IsTest
    static void putSwitchesAFieldBetweenPlainAndContextAwareAndCopyCarriesIt() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_LiteralExpression('plain'))
                .put(Account.Name, new XFTY_CopyFromSiblingExpression(Account.AccountNumber)); // now context-aware

        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Account.Name));
        Assert.isTrue(template.contextAwareBySObjectFieldMap.containsKey(Account.Name));

        XFTY_DummySObjectMasterTemplate copy = template.copy();
        Assert.isTrue(copy.contextAwareBySObjectFieldMap.containsKey(Account.Name),
                'the copy carries the context-aware entry');
    }

    @IsTest
    static void untypedPutRejectsARelationship() {
        try {
            new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.AccountId, (Object) new XFTY_DummyDefaultRelationship(new Account()));
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('putRequired'), ex.getMessage());
        }
    }

    @IsTest
    static void removeClearsAFieldFromEveryMap() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_LiteralExpression('Doe'))
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));

        template.remove(Contact.LastName);
        template.remove(Contact.AccountId);

        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Contact.LastName));
        Assert.isFalse(template.requiredRelationshipBySObjectFieldMap.containsKey(Contact.AccountId));
        Assert.isFalse(new Set<SObjectField>(template.orderedValueFields()).contains(Contact.LastName));
    }

    @IsTest
    static void orderedValueFieldsFollowsPutOrderAcrossPutRemoveAndCopy() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_LiteralExpression('n'))
                .put(Account.Industry, new XFTY_LiteralExpression('i'))
                .put(Account.Type, new XFTY_LiteralExpression('t'));

        Assert.areEqual(
                new List<SObjectField>{ Account.Name, Account.Industry, Account.Type },
                template.orderedValueFields()
        );

        template.remove(Account.Industry);
        template.put(Account.Name, new XFTY_LiteralExpression('n2')); // re-put keeps its place
        Assert.areEqual(
                new List<SObjectField>{ Account.Name, Account.Type },
                template.orderedValueFields()
        );

        XFTY_DummySObjectMasterTemplate copy = template.copy();
        copy.put(Account.Rating, new XFTY_LiteralExpression('r'));
        Assert.areEqual(
                new List<SObjectField>{ Account.Name, Account.Type },
                template.orderedValueFields(),
                'the original is unchanged by the copy'
        );
        Assert.areEqual(
                new List<SObjectField>{ Account.Name, Account.Type, Account.Rating },
                copy.orderedValueFields()
        );
    }

    @IsTest
    static void putWrapsABareLiteralAsAnExactValue() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Type, 'Customer');

        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Account.Type));
        Assert.areEqual('Customer', template.defaultBySObjectFieldMap.get(Account.Type).get());
    }

    @IsTest
    static void putDoesNotDoubleWrapAnExistingStrategyPassedAsObject() {
        XFTY_ValueExpressionIntf strategy = new XFTY_IncrementingStringExpression('Acct');

        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, (Object) strategy);

        Assert.areEqual(strategy, template.defaultBySObjectFieldMap.get(Account.Name));
    }

    @IsTest
    static void putRequiredAndPutOptionalRouteToTheirOwnMaps() {
        XFTY_DummyDefaultRelationship required = new XFTY_DummyDefaultRelationship(new Account());
        XFTY_DummyDefaultRelationship optional = new XFTY_DummyDefaultRelationship(new Contact());

        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .putRequired(Contact.AccountId, required)
                .putOptional(Contact.ReportsToId, optional);

        Assert.areEqual(required, template.requiredRelationshipBySObjectFieldMap.get(Contact.AccountId));
        Assert.areEqual(optional, template.optionalRelationshipBySObjectFieldMap.get(Contact.ReportsToId));
        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Contact.AccountId));
    }

    @IsTest
    static void copyIsIndependentOfTheOriginal() {
        XFTY_DummySObjectMasterTemplate original = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_LiteralExpression('Original'));

        XFTY_DummySObjectMasterTemplate copy = original.copy();
        copy.put(Account.Industry, new XFTY_LiteralExpression('Tech'));
        copy.remove(Account.Name);

        // The copy reflects its own edits...
        Assert.isTrue(copy.defaultBySObjectFieldMap.containsKey(Account.Industry));
        Assert.isFalse(copy.defaultBySObjectFieldMap.containsKey(Account.Name));

        // ...while the original is untouched.
        Assert.isFalse(original.defaultBySObjectFieldMap.containsKey(Account.Industry));
        Assert.isTrue(original.defaultBySObjectFieldMap.containsKey(Account.Name));
        Assert.areEqual(Account.Id, copy.primaryTargetField);
    }
}
