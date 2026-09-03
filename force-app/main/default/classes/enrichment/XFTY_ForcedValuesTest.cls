/**
 * Proves `XFTY_ForcedValues` - placing the config's forced scalars on the
 * injector for a position. In-memory; the injector round-trip is exercised, no
 * DML/SOQL.
 */
@IsTest
private class XFTY_ForcedValuesTest {

    @IsTest
    static void testApplyRecordValues_appliesOnRecordScalars() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectValue(Contact.LastActivityDate, Date.newInstance(2020, 1, 1));
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Contact(LastName = 'X') });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyRecordValues(injector, 1);
        Test.stopTest();

        // Assert
        Assert.areEqual(Date.newInstance(2020, 1, 1), ((Contact) injector.result()[0]).LastActivityDate);
    }

    @IsTest
    static void testApplyAncestorValues_atAMatchingAncestorPosition_appliesTheValue() {
        // Arrange - injectValue(path) targets the record at path's relationship prefix
        List<SObjectField> pathToField = new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue };
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(pathToField, 5000);
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Account(Name = 'A') });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyAncestorValues(injector, new List<SObjectField>{ Contact.AccountId }, 1);
        Test.stopTest();

        // Assert
        Assert.areEqual(5000, ((Account) injector.result()[0]).AnnualRevenue);
    }

    @IsTest
    static void testApplyAncestorValues_atANonMatchingPosition_appliesNothing() {
        // Arrange
        List<SObjectField> pathToField = new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue };
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(pathToField, 5000);
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Account(Name = 'A') });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyAncestorValues(injector, new List<SObjectField>{ Contact.OwnerId }, 1);
        Test.stopTest();

        // Assert
        Assert.isNull(((Account) injector.result()[0]).AnnualRevenue);
    }

    @IsTest
    static void testApplyChildValues_atAMatchingChildPosition_appliesTheValueToEveryRow() {
        // Arrange - injectChildValue(childField, leafField, literal) - every child gets it
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectChildValue(Contact.AccountId, Contact.Description, 'shared');
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{
                new Contact(LastName = 'A'), new Contact(LastName = 'B')
        });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyChildValues(injector, new List<SObjectField>{ Contact.AccountId }, 2);
        Test.stopTest();

        // Assert
        List<SObject> enriched = injector.result();
        Assert.areEqual('shared', ((Contact) enriched[0]).Description);
        Assert.areEqual('shared', ((Contact) enriched[1]).Description);
    }

    @IsTest
    static void testApplyChildValues_withAnExpression_resolvesItFreshPerChild() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectChildValue(Contact.AccountId, Contact.Description, new XFTY_IncrementingStringExpression('n'));
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{
                new Contact(LastName = 'A'), new Contact(LastName = 'B')
        });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyChildValues(injector, new List<SObjectField>{ Contact.AccountId }, 2);
        Test.stopTest();

        // Assert
        List<SObject> enriched = injector.result();
        Assert.areEqual('n 1', ((Contact) enriched[0]).Description);
        Assert.areEqual('n 2', ((Contact) enriched[1]).Description, 'each child gets its own resolution');
    }

    @IsTest
    static void testApplyChildValues_withAPerRowList_appliesOneValuePerChild() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectChildValue(Contact.AccountId, Contact.Description, new List<Object>{ 'first', 'second' });
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{
                new Contact(LastName = 'A'), new Contact(LastName = 'B')
        });

        // Act
        Test.startTest();
        new XFTY_ForcedValues(config).applyChildValues(injector, new List<SObjectField>{ Contact.AccountId }, 2);
        Test.stopTest();

        // Assert
        List<SObject> enriched = injector.result();
        Assert.areEqual('first', ((Contact) enriched[0]).Description);
        Assert.areEqual('second', ((Contact) enriched[1]).Description);
    }

    @IsTest
    static void testAssertEveryPathWasReached_whenAnAncestorValueNeverMatched_throws() {
        // Arrange - the path was never visited (applyAncestorValues never called for it)
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(
                new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue }, 5000
        );
        XFTY_ForcedValues forcedValues = new XFTY_ForcedValues(config);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            forcedValues.assertEveryPathWasReached();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('injectValue'), 'the error names the unreached path');
    }

    @IsTest
    static void testAssertEveryPathWasReached_whenEveryPathMatched_doesNotThrow() {
        // Arrange
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectChildValue(Contact.AccountId, Contact.Description, 'x');
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(new List<SObject>{ new Contact(LastName = 'A') });
        XFTY_ForcedValues forcedValues = new XFTY_ForcedValues(config);
        forcedValues.applyChildValues(injector, new List<SObjectField>{ Contact.AccountId }, 1);

        // Act
        Test.startTest();
        forcedValues.assertEveryPathWasReached();
        Test.stopTest();

        // Assert
        Assert.isTrue(true, 'no exception - every path was reached');
    }
}
