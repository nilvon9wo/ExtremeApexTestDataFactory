/**
 * Proves `XFTY_ForcedValues` - placing the config's forced scalars on the
 * injector for a position. In-memory; the injector round-trip is exercised, no
 * DML/SOQL.
 */
@IsTest
private class XFTY_ForcedValuesTest {

    @IsTest
    static void testApplyTo_atTheRoot_appliesOnRecordValues() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(Contact.LastActivityDate, Date.newInstance(2020, 1, 1));
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Contact(LastName = 'X') });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyTo(injector, new List<SObjectField>(), true);
        Test.stopTest();

        // Assert
        Assert.areEqual(Date.newInstance(2020, 1, 1), ((Contact) injector.result()[0]).LastActivityDate);
    }

    @IsTest
    static void testApplyTo_notAtTheRoot_doesNotApplyOnRecordValues() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(Contact.LastActivityDate, Date.newInstance(2020, 1, 1));
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Contact(LastName = 'X') });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyTo(injector, new List<SObjectField>{ Contact.AccountId }, false);
        Test.stopTest();

        // Assert
        Assert.isNull(((Contact) injector.result()[0]).LastActivityDate, 'on-record values are the target record only');
    }

    @IsTest
    static void testApplyTo_atAMatchingAncestorPosition_appliesTheAncestorValue() {
        // Arrange - injectValue(path) targets the record at path's relationship prefix
        List<SObjectField> pathToField = new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue };
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(pathToField, 5000);
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Account(Name = 'A') });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyTo(injector, new List<SObjectField>{ Contact.AccountId }, false);
        Test.stopTest();

        // Assert
        Assert.areEqual(5000, ((Account) injector.result()[0]).AnnualRevenue);
    }

    @IsTest
    static void testApplyTo_atANonMatchingPosition_doesNotApplyTheAncestorValue() {
        // Arrange
        List<SObjectField> pathToField = new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue };
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(pathToField, 5000);
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Account(Name = 'A') });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyTo(injector, new List<SObjectField>{ Contact.OwnerId }, false);
        Test.stopTest();

        // Assert
        Assert.isNull(((Account) injector.result()[0]).AnnualRevenue);
    }

    @IsTest
    static void testApplyTo_whenTheValueIsAnExpression_resolvesItThroughGet() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectValue(Account.Name, new XFTY_LiteralExpression('Resolved'));
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Account() });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyTo(injector, new List<SObjectField>(), true);
        Test.stopTest();

        // Assert
        Assert.areEqual('Resolved', ((Account) injector.result()[0]).Name);
    }
}
