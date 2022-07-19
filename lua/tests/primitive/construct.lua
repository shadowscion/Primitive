
return {
    groupName = "construct",

    cases = {
        {
            name = "Should return a valid (error model) construct if invalid parameters are given",

            func = function()

                local succ, result = Primitive.construct.get( "i_do_not_exist" )

                expect( succ ).to.beTrue()

                expect( result ).to.beA( "table" )

                expect( result.error ).to.exist()
                expect( result.error ).to.beA( "table" )

                expect( result.convexes ).to.exist()
                expect( result.convexes ).to.beA( "table" )
                expect( table.IsSequential( result.convexes ) ).to.beTrue()

            end
        },

        {
            name = "Should return a valid (error model) construct if invalid return from factory function",

            func = function()

                local fake = {
                    data = { name = "fake_name_for_test" },

                    factory = function( param, data, threaded, physics )
                        local model = {}
                        return model
                    end,
                }

                local succ, result = Primitive.construct.generate( fake, {}, false, true )

                expect( succ ).to.beTrue()

                expect( result ).to.beA( "table" )

                expect( result.error ).to.exist()
                expect( result.error ).to.beA( "table" )

                expect( result.convexes ).to.exist()
                expect( result.convexes ).to.beA( "table" )
                expect( table.IsSequential( result.convexes ) ).to.beTrue()

            end
        },

        {
            name = "Should return a valid (error model) construct if error in factory function",

            func = function()

                local fake = {
                    data = { name = "fake_name_for_test" },

                    factory = function( param, data, threaded, physics )
                        local model = {}

                        error( "test_fake_error" )

                        return model
                    end,
                }

                local succ, result = Primitive.construct.generate( fake, {}, false, true )

                expect( succ ).to.beTrue()

                expect( result ).to.beA( "table" )

                expect( result.error ).to.exist()
                expect( result.error ).to.beA( "table" )

                expect( result.convexes ).to.exist()
                expect( result.convexes ).to.beA( "table" )
                expect( table.IsSequential( result.convexes ) ).to.beTrue()

            end
        },
    }
}
