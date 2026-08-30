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
                .put(Contact.LastName, new XFTY_DummyDefaultValueExact('Doe'))
                .put(Contact.AccountId, new XFTY_DummyDefaultRelationshipRequired(new Account()))
                .put(Contact.ReportsToId, new XFTY_DummyDefaultRelationshipOptional(new Contact()));

        Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(Contact.LastName));
        Assert.isTrue(template.requiredRelationshipBySObjectFieldMap.containsKey(Contact.AccountId));
        Assert.isTrue(template.optionalRelationshipBySObjectFieldMap.containsKey(Contact.ReportsToId));
    }

    @IsTest
    static void removeClearsAFieldFromEveryMap() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_DummyDefaultValueExact('Doe'))
                .put(Contact.AccountId, new XFTY_DummyDefaultRelationshipRequired(new Account()));

        template.remove(Contact.LastName);
        template.remove(Contact.AccountId);

        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Contact.LastName));
        Assert.isFalse(template.requiredRelationshipBySObjectFieldMap.containsKey(Contact.AccountId));
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
        XFTY_DummyDefaultValueIntf strategy = new XFTY_DummyDefaultValueIncrementingString('Acct');

        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, (Object) strategy);

        Assert.areEqual(strategy, template.defaultBySObjectFieldMap.get(Account.Name));
    }

    @IsTest
    static void putRoutesARelationshipObjectPassedAsObject() {
        Object relationship = new XFTY_DummyDefaultRelationshipRequired(new Account());

        XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.AccountId, relationship);

        Assert.isTrue(template.requiredRelationshipBySObjectFieldMap.containsKey(Contact.AccountId));
        Assert.isFalse(template.defaultBySObjectFieldMap.containsKey(Contact.AccountId));
    }

    @IsTest
    static void copyIsIndependentOfTheOriginal() {
        XFTY_DummySObjectMasterTemplate original = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_DummyDefaultValueExact('Original'));

        XFTY_DummySObjectMasterTemplate copy = original.copy();
        copy.put(Account.Industry, new XFTY_DummyDefaultValueExact('Tech'));
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
