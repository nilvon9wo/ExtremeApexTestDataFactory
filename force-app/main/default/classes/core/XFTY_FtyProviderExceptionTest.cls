/**
 * Coverage for the framework's base exception type. It is thrown and caught
 * across the suite; this pins its constructability and hierarchy.
 */
@IsTest
private class XFTY_FtyProviderExceptionTest {

    @IsTest
    static void isAConstructableExceptionSubclass() {
        try {
            throw new XFTY_DummySObjectFtyProviderException('boom');
        } catch (Exception ex) {
            Assert.isInstanceOfType(ex, XFTY_DummySObjectFtyProviderException.class);
            Assert.areEqual('boom', ex.getMessage());
        }
    }
}
