/**
 * Proves the framework's base exception type is a constructable `Exception`
 * subclass. It is thrown and caught across the suite; this pins the hierarchy.
 */
@IsTest
private class XFTY_FtyProviderExceptionTest {

    @IsTest
    static void testConstructor_whenGivenAMessage_producesACatchableExceptionSubclassCarryingIt() {
        // Arrange
        // nothing to arrange

        // Act
        Exception thrown;
        Test.startTest();
        try {
            throw new XFTY_DummySObjectFtyProviderException('boom');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isInstanceOfType(thrown, XFTY_DummySObjectFtyProviderException.class);
        Assert.areEqual('boom', thrown.getMessage());
    }
}
